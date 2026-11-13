"""Redmine operator: has agents work on the tickets of Redmine, in sandboxes.

A RedmineProject names a project in Redmine and a warm pool of sandboxes. Every
open ticket in that project assigned to the operator's own Redmine user (the
owner of the API key it is given) gets a sandbox claimed from the warm pool.
The sandbox runs an agent, opencode, as a server. The operator hands it the
ticket, posts its replies on the ticket as notes, and hands it what others add
to the ticket: notes, and changes of its subject, description and attachments.
Once the ticket is closed, or assigned to someone else, the sandbox is deleted
again.

https://kopf.readthedocs.io
https://www.redmine.org/projects/redmine/wiki/Rest_api
https://opencode.ai/docs/api/
"""

import base64
import logging
import os
import secrets

import aiohttp
import kopf
from kubernetes_asyncio import client, config
from kubernetes_asyncio.client.exceptions import ApiException

# A ticket's sandbox is a SandboxClaim of agent-sandbox, owned by the
# RedmineProject and labelled with the ticket, as is its pod.
CLAIMS = {
    "group": "extensions.agents.x-k8s.io",
    "version": "v1beta1",
    "plural": "sandboxclaims",
}
PROJECT_LABEL = "agents.internal/redmine-project"
TICKET_LABEL = "agents.internal/redmine-ticket"
POD_TICKET_LABEL = "sandbox.users.io/redmine-ticket"

# The agent in a sandbox: opencode's server, working in the sandbox's
# workspace. The password of the servers in a namespace is in a Secret there,
# which the operator makes up.
AGENT_PORT = 4096
AGENT_SECRET = "agent-server"
WORKSPACE = "/workspace"


@kopf.on.startup()
async def start(settings: kopf.OperatorSettings, memo: kopf.Memo, **_):
    # Only post warnings as Kubernetes events, not every run of the timer
    settings.posting.level = logging.WARNING
    # The namespace and resource to watch are known; scanning the cluster for
    # them would take permissions to list all namespaces and resource types.
    settings.scanning.disabled = True
    config.load_incluster_config()
    kubernetes = client.ApiClient()
    memo.claims = client.CustomObjectsApi(kubernetes)
    memo.core = client.CoreV1Api(kubernetes)
    memo.redmine = aiohttp.ClientSession(
        os.environ["REDMINE_URL"],
        headers={"X-Redmine-API-Key": os.environ["REDMINE_API_KEY"].strip()},
        raise_for_status=True,
        timeout=aiohttp.ClientTimeout(total=30),
    )
    memo.me = None
    memo.agents = {}


@kopf.on.cleanup()
async def stop(memo: kopf.Memo, **_):
    await memo.redmine.close()
    for agents in memo.agents.values():
        await agents.close()
    await memo.claims.api_client.close()


async def get(memo, path, **params):
    async with memo.redmine.get(path, params=params) as response:
        return await response.json()


async def whoami(memo):
    """The id of the operator's Redmine user."""
    if memo.me is None:
        memo.me = (await get(memo, "/users/current.json"))["user"]["id"]
    return memo.me


async def tickets(memo, project):
    """The open tickets of a project assigned to the operator, by id."""
    found, offset = {}, 0
    while True:
        page = await get(
            memo,
            "/issues.json",
            project_id=project,
            subproject_id="!*",
            assigned_to_id="me",
            status_id="open",
            limit=100,
            offset=offset,
        )
        found |= {ticket["id"]: ticket for ticket in page["issues"]}
        offset += page["limit"]
        if offset >= page["total_count"]:
            return found


async def started_status(memo, spec, ticket, statuses):
    """The status to move a ticket to as its sandbox starts, if any.

    Only tickets still in the default status of their tracker, i.e. new ones,
    are moved; the status is named in the RedmineProject.
    """
    if spec.get("inProgressStatus") not in statuses:
        return None
    trackers = await get(memo, "/trackers.json")
    defaults = {
        tracker["id"]: tracker["default_status"]["id"]
        for tracker in trackers["trackers"]
        if "default_status" in tracker
    }
    if ticket["status"]["id"] != defaults.get(ticket["tracker"]["id"]):
        return None
    return statuses[spec["inProgressStatus"]]


async def update(memo, ticket_id, logger, **changes):
    """Update a ticket, keeping at least the note if the rest is refused."""
    try:
        async with memo.redmine.put(f"/issues/{ticket_id}.json", json={"issue": changes}):
            return
    except aiohttp.ClientResponseError as error:
        if error.status != 422 or "notes" not in changes or changes.keys() == {"notes"}:
            # e.g. the ticket was deleted
            logger.warning(f"Could not update ticket #{ticket_id}: {error.status} {error.message}")
            return
        # The workflow does not allow the change of status
        logger.warning(f"Could not change the status of ticket #{ticket_id}")
    await update(memo, ticket_id, logger, notes=changes["notes"])


async def agents(memo, namespace):
    """A client for the agents in a namespace, knowing their password."""
    if namespace not in memo.agents:
        try:
            secret = await memo.core.read_namespaced_secret(AGENT_SECRET, namespace)
        except ApiException as error:
            if error.status != 404:
                raise
            # The sandboxes wait for it to start
            secret = await memo.core.create_namespaced_secret(
                namespace,
                client.V1Secret(
                    metadata=client.V1ObjectMeta(name=AGENT_SECRET),
                    string_data={"password": secrets.token_urlsafe(32)},
                ),
            )
        password = base64.b64decode(secret.data["password"]).decode()
        memo.agents[namespace] = aiohttp.ClientSession(
            auth=aiohttp.BasicAuth("opencode", password),
            raise_for_status=True,
            timeout=aiohttp.ClientTimeout(total=30, sock_connect=5),
        )
    return memo.agents[namespace]


def address(claim):
    """Where the agent of a claimed sandbox is, once it is ready."""
    status = claim.get("status", {})
    ready = any(
        condition["type"] == "Ready" and condition["status"] == "True"
        for condition in status.get("conditions", [])
    )
    addresses = status.get("sandbox", {}).get("podIPs") or []
    if ready and addresses:
        host = f"[{addresses[0]}]" if ":" in addresses[0] else addresses[0]
        return f"http://{host}:{AGENT_PORT}"
    return None


class Agent:
    """The agent of a ticket: a session of the opencode server in its sandbox."""

    def __init__(self, http, url, ticket_id):
        self.http = http
        self.url = f"{url}/api/session"
        self.session = f"ses_redmine_{ticket_id}"

    async def call(self, method, path="", **kwargs):
        async with self.http.request(method, f"{self.url}{path}", **kwargs) as response:
            if response.content_type == "application/json":
                return await response.json()
            return None

    async def info(self):
        """The session, if it has been started."""
        try:
            return (await self.call("GET", f"/{self.session}"))["data"]
        except aiohttp.ClientResponseError as error:
            if error.status == 404:
                return None
            raise

    async def start(self):
        await self.call("POST", json={"id": self.session, "location": {"directory": WORKSPACE}})

    async def prompt(self, text, journal):
        """Hand the agent a message, which steers it if it is at work already.

        The message is marked with the last journal of the ticket it includes.
        """
        await self.call("POST", f"/{self.session}/prompt", json={"text": text, "metadata": {"journal": journal}})

    async def busy(self):
        return self.session in (await self.call("GET", "/active"))["data"]

    async def messages(self, after=None, **filters):
        """The messages of the session, oldest first: all, or those after one."""
        found, query = [], {"order": "desc", **filters}
        while True:
            page = await self.call("GET", f"/{self.session}/message", params=query)
            for message in page["data"]:
                if message["id"] == after:
                    return found[::-1]
                found.append(message)
            if not page["data"] or not page["cursor"].get("next"):
                return found[::-1]
            query = {"cursor": page["cursor"]["next"], **filters}

    async def remember(self, info, **metadata):
        """Keep something in the session's metadata."""
        await self.call("PATCH", f"/{self.session}", json={"metadata": (info.get("metadata") or {}) | metadata})


def author(journal):
    return journal.get("user") or {"id": None, "name": "Anonymous"}


def name(journal, me):
    return author(journal)["name"] + (" (you)" if author(journal)["id"] == me else "")


def note(journal, me):
    """A journal's note, if everyone can see it, as the agent's replies are public."""
    if journal.get("notes") and not journal.get("private_notes"):
        return f"Note by {name(journal, me)}:\n\n{journal['notes']}"
    return None


def download(attachment_id, filename):
    return f"$REDMINE_URL/attachments/download/{attachment_id}/{filename}"


def told(journal, me):
    """What a journal of a ticket tells its agent, if anything: its note, and
    changes of the subject, description and attachments."""
    parts = [note(journal, me)]
    for detail in journal.get("details", []):
        if detail["property"] == "attr" and detail["name"] == "subject":
            parts.append(f"{name(journal, me)} changed the subject to: {detail.get('new_value')}")
        elif detail["property"] == "attr" and detail["name"] == "description":
            parts.append(f"{name(journal, me)} changed the description to:\n\n{detail.get('new_value') or ''}")
        elif detail["property"] == "attachment" and detail.get("new_value"):
            parts.append(f"{name(journal, me)} attached {detail['new_value']}: {download(detail['name'], detail['new_value'])}")
    return "\n\n".join(part for part in parts if part)


def brief(issue, me):
    """The first message to the agent of a ticket: the ticket so far."""
    sections = [
        f"You have been assigned ticket #{issue['id']} in Redmine: {issue['subject']}\n\n"
        f"Project: {issue['project']['name']}. Tracker: {issue['tracker']['name']}. "
        f"Status: {issue['status']['name']}. Author: {issue['author']['name']}."
    ]
    if issue.get("description"):
        sections.append(issue["description"])
    if issue.get("attachments"):
        sections.append(
            "Attachments:\n\n"
            + "\n".join(f"- {a['filename']}: {download(a['id'], a['filename'])}" for a in issue["attachments"])
        )
    sections += [text for text in (note(journal, me) for journal in issue.get("journals", [])) if text]
    return "\n\n---\n\n".join(sections)


def said(message):
    """What the agent said in a message."""
    return "\n\n".join(part["text"] for part in message.get("content", []) if part.get("type") == "text").strip()


async def report(memo, spec, agent, info, ticket, statuses, logger):
    """Post what the agent replied since it last did, once it has stopped.

    Returns the status the ticket was moved to, if any.
    """
    unreported = await agent.messages(after=(info.get("metadata") or {}).get("reported"))
    if not unreported:
        return None
    last = unreported[-1]
    if last["type"] == "assistant" and last.get("finish") == "error":
        # The sandbox restarted while the agent was at work, which leaves the
        # step it was at broken off
        await agent.prompt("Your sandbox was restarted while you were working. Carry on.", journal=0)
        logger.info(f"Had the agent of ticket #{ticket['id']} carry on")
        return None
    if not any(message["type"] == "idle" for message in unreported):
        return None
    replies = [
        said(message)
        for message in unreported
        if message["type"] == "assistant" and message.get("finish") in ("stop", "length")
    ]
    replies = [reply for reply in replies if reply]
    for message in unreported:
        if message["type"] == "idle" and message.get("outcome") == "failed":
            replies.append(f"The agent failed: {(message.get('error') or {}).get('message', 'unknown error')}")
        elif message["type"] == "idle" and message.get("outcome") == "interrupted":
            replies.append("The agent was interrupted.")
    changes = {"notes": "\n\n---\n\n".join(replies or ["The agent stopped without a reply."])}
    feedback = statuses.get(spec.get("feedbackStatus"))
    if feedback is not None and feedback != ticket["status"]["id"]:
        changes["status_id"] = feedback
    await update(memo, ticket["id"], logger, **changes)
    await agent.remember(info, reported=unreported[-1]["id"])
    logger.info(f"Posted the reply of the agent of ticket #{ticket['id']}")
    return changes.get("status_id")


async def work(memo, spec, http, ticket, claim, statuses, logger):
    """Keep a ticket and the agent working on it in step."""
    url = address(claim)
    if url is None:
        return
    agent = Agent(http, url, ticket["id"])
    me = await whoami(memo)
    issue = (await get(memo, f"/issues/{ticket['id']}.json", include="journals,attachments"))["issue"]
    journals = issue.get("journals", [])

    info = await agent.info()
    if info is None:
        await agent.start()
    handed = [] if info is None else await agent.messages(type="user")
    if not handed:
        await agent.prompt(brief(issue, me), journal=max((journal["id"] for journal in journals), default=0))
        logger.info(f"Handed ticket #{ticket['id']} to its agent")
        return

    status = ticket["status"]["id"]
    if not await agent.busy():
        status = await report(memo, spec, agent, info, ticket, statuses, logger) or status

    last = max((message.get("metadata") or {}).get("journal", 0) for message in handed)
    new = [
        journal
        for journal in journals
        if journal["id"] > last and author(journal)["id"] != me and told(journal, me)
    ]
    if new:
        await agent.prompt("\n\n---\n\n".join(told(journal, me) for journal in new), journal=new[-1]["id"])
        logger.info(f"Handed the updates of ticket #{ticket['id']} to its agent")
        if status == statuses.get(spec.get("feedbackStatus")) and spec.get("inProgressStatus") in statuses:
            await update(memo, ticket["id"], logger, status_id=statuses[spec["inProgressStatus"]])


@kopf.timer("agents.internal", "v1alpha1", "redmineprojects", interval=30)
async def sync(spec, name, namespace, body, memo, patch, logger, **_):
    """Make the sandboxes of a RedmineProject, and their agents, follow its tickets."""
    # Before anything else, as sandboxes only start once their password exists
    http = await agents(memo, namespace)
    open_tickets = await tickets(memo, spec["project"])
    statuses = {status["name"]: status["id"] for status in (await get(memo, "/issue_statuses.json"))["issue_statuses"]}
    listed = await memo.claims.list_namespaced_custom_object(
        namespace=namespace,
        label_selector=f"{PROJECT_LABEL}={name}",
        **CLAIMS,
    )
    claims = {int(claim["metadata"]["labels"][TICKET_LABEL]): claim for claim in listed["items"]}

    for ticket_id in sorted(open_tickets.keys() - claims.keys()):
        claim = {
            "apiVersion": f"{CLAIMS['group']}/{CLAIMS['version']}",
            "kind": "SandboxClaim",
            "metadata": {
                "name": f"redmine-{ticket_id}",
                "labels": {PROJECT_LABEL: name, TICKET_LABEL: str(ticket_id)},
            },
            "spec": {
                "warmPoolRef": {"name": spec["warmPool"]},
                "additionalPodMetadata": {"labels": {POD_TICKET_LABEL: str(ticket_id)}},
            },
        }
        kopf.adopt(claim, owner=body)
        await memo.claims.create_namespaced_custom_object(namespace=namespace, body=claim, **CLAIMS)
        logger.info(f"Claimed a sandbox for ticket #{ticket_id}")
        changes = {
            "notes": f"Started the sandbox `{claim['metadata']['name']}` (namespace `{namespace}`) for this ticket; its agent replies here."
        }
        status = await started_status(memo, spec, open_tickets[ticket_id], statuses)
        if status is not None:
            changes["status_id"] = status
        await update(memo, ticket_id, logger, **changes)

    for ticket_id in sorted(claims.keys() - open_tickets.keys()):
        claim_name = claims[ticket_id]["metadata"]["name"]
        try:
            await memo.claims.delete_namespaced_custom_object(namespace=namespace, name=claim_name, **CLAIMS)
        except ApiException as error:
            if error.status != 404:
                raise
        logger.info(f"Deleted the sandbox of ticket #{ticket_id}")
        await update(
            memo,
            ticket_id,
            logger,
            notes=f"Deleted the sandbox `{claim_name}`, as this ticket is no longer open and assigned to me.",
        )

    for ticket_id in sorted(claims.keys() & open_tickets.keys()):
        try:
            await work(memo, spec, http, open_tickets[ticket_id], claims[ticket_id], statuses, logger)
        except (aiohttp.ClientError, TimeoutError) as error:
            logger.warning(f"Could not get on with ticket #{ticket_id}: {error!r}")

    patch.status["tickets"] = sorted(open_tickets)
