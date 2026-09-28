{
  config,
  lib,
  pkgs,
  secrets,
  nixpkgs-2605,
  chan-quectel,
  ...
}: let
  # Asterisk 22 LTS with chan_quectel, which must be built against the exact
  # Asterisk it is loaded into
  pkgs2605 = nixpkgs-2605.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  asterisk = pkgs2605.callPackage ./asterisk.nix {
    chan-quectel = pkgs2605.callPackage ./chan-quectel.nix {src = chan-quectel;};
  };

  stateDir = "/var/lib/asterisk-quectel";

  # SIP only from the home LAN, never over IPv6
  acl = prefix: ''
    ${prefix}deny = 0.0.0.0/0
    ${prefix}deny = ::/0
    ${prefix}permit = 192.168.178.0/24
  '';

  # International numbers have 7 to 15 digits. Only fixed length digit
  # patterns: `.` would also match `&` and let the phone add Dial() targets.
  international = lib.concatMapStrings (n: let
    digits = "Z" + lib.concatStrings (lib.replicate (n - 1) "X");
  in ''
    exten => _00${digits},1,Gosub(quectel-dial,s,1(+''${EXTEN:2}))
    exten => _+${digits},1,Gosub(quectel-dial,s,1(''${EXTEN}))
  '') (lib.range 7 15);
in {
  # A Quectel EC25-EUX modem (USB) as VoLTE trunk for one SIP phone.
  #
  # Set once on the modem, saved there: AT+QMBNCFG="Select","ROW_Generic_3GPP",
  # AT+QCFG="ims",1 and AT+QCFG="USBCFG",0x2C7C,0x0125,1,1,1,1,1,0,1 (USB
  # sound card), then AT+CFUN=1,1.
  #
  # The service is not restarted on switch: `systemctl restart asterisk`.
  # Send an SMS: asterisk -rx 'quectel sms send quectel0 +45... "text"'.
  services.asterisk = {
    enable = true;
    package = asterisk;
    # Outside /var/lib/asterisk, which is re-seeded from the package
    extraConfig = ''
      astdbdir => ${stateDir}
    '';
    # Samples only for what core Asterisk and PJSIP read at startup
    useTheseDefaultConfFiles = ["acl.conf" "ccss.conf" "cdr.conf" "cel.conf" "features.conf" "indications.conf" "pjproject.conf" "udptl.conf"];
    confFiles = {
      # Only what this setup uses
      "modules.conf" = ''
        [modules]
        autoload = no
        load = chan_quectel.so
        load = chan_pjsip.so
        load = res_pjproject.so
        load = res_pjsip.so
        load = res_pjsip_acl.so
        load = res_pjsip_authenticator_digest.so
        load = res_pjsip_caller_id.so
        load = res_pjsip_endpoint_identifier_user.so
        load = res_pjsip_logger.so
        load = res_pjsip_nat.so
        load = res_pjsip_pubsub.so
        load = res_pjsip_registrar.so
        load = res_pjsip_rfc3326.so
        load = res_pjsip_sdp_rtp.so
        load = res_pjsip_session.so
        load = res_rtp_asterisk.so
        load = res_sorcery_astdb.so
        load = res_sorcery_config.so
        load = res_sorcery_memory.so
        load = res_timing_timerfd.so
        load = bridge_simple.so
        load = codec_alaw.so
        load = codec_ulaw.so
        load = pbx_config.so
        load = app_dial.so
        load = app_exec.so
        load = app_stack.so
        load = func_callerid.so
        load = func_env.so
        load = func_json.so
        load = func_logic.so
        load = func_strings.so
      '';

      "logger.conf" = ''
        [logfiles]
        syslog.local0 => notice,warning,error,verbose(2)
      '';

      "rtp.conf" = ''
        [general]
        rtpstart = 10000
        rtpend = 10049
      '';

      "pjsip.conf" = ''
        [transport-udp]
        type = transport
        protocol = udp
        bind = 0.0.0.0:5060

        [lan]
        type = acl
        ${acl ""}
        [linphone]
        type = endpoint
        context = linphone
        auth = linphone
        aors = linphone
        disallow = all
        allow = ulaw,alaw
        direct_media = no
        rtp_symmetric = yes
        force_rport = yes
        rewrite_contact = yes
        ; Frees the modem's line if the phone drops off mid-call
        rtp_timeout = 30
        rtp_timeout_hold = 300
        ${acl "contact_"}
        [linphone]
        type = aor
        max_contacts = 1
        remove_existing = yes
        qualify_frequency = 60

        [linphone]
        type = auth
        auth_type = digest
        username = linphone
        #include "${config.age.secrets.asterisk-pjsip-auth.path}"
      '';

      "quectel.conf" = ''
        [general]
        smsdb = ${stateDir}/smsdb

        [quectel0]
        data = /dev/quectel-at
        ; Voice over the modem's USB sound card
        uac = yes
        alsadev = hw:EC25EUX
        context = quectel-incoming
        ; SMS stay in the modem until the dialplan has logged them
        msg_direct = off
        msg_storage = me
        autodeletesms = no
        ; Turns call waiting off for the SIM at the operator (AT+CCWA=0,0,1):
        ; chan_quectel does not hang up correctly with two calls
        callwaiting = no
      '';

      "extensions.conf" = ''
        [quectel-incoming]
        ; Calls arrive at the SIM's own number (AT+CNUM), not at s
        exten => _[+0-9].,1,Goto(s,1)
        exten => s,1,Set(CALLERID(name)=''${CALLERID(num)})
         same => n,Set(CONTACTS=''${PJSIP_DIAL_CONTACTS(linphone)})
         same => n,ExecIf($["''${CONTACTS}" = ""]?Hangup(17))
         same => n,Dial(''${CONTACTS},60)
         same => n,Hangup()
        ; chan_quectel passes the SMS as JSON: log it as one line, then
        ; delete it from the modem
        exten => sms,1,Set(FILE(${stateDir}/sms.jsonl,,,al,u)=''${SMS})
         same => n,QUECTEL_DELETE_SMS(quectel0,''${FILTER(0-9,''${JSON_DECODE(SMS,idx)})})
         same => n,Hangup()

        [linphone]
        exten => _[2-9]XXXXXXX,1,Gosub(quectel-dial,s,1(+45''${EXTEN}))
        ${international}
        exten => 112,1,Gosub(quectel-dial,s,1(112))
        exten => 114,1,Gosub(quectel-dial,s,1(114))
        exten => 1813,1,Gosub(quectel-dial,s,1(1813))

        [quectel-dial]
        exten => s,1,Dial(Quectel/quectel0/''${ARG1})
         ; 503 instead of 603 when the modem is unavailable
         same => n,Hangup(''${IF($["''${DIALSTATUS}" = "CHANUNAVAIL"]?34:16)})
      '';
    };
  };

  # Asterisk drops to its user with initgroups(), so these apply: dialout for
  # the AT port, audio for the sound card
  users.users.asterisk.extraGroups = ["dialout" "audio"];

  services.udev.extraRules = ''
    # Keep ModemManager off the modem, and never autosuspend it
    ACTION!="remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="2c7c", ATTR{idProduct}=="0125", ENV{ID_MM_DEVICE_IGNORE}="1", ATTR{power/control}="on"
    # Stable name for the AT port (USB interface 02)
    ACTION!="remove", SUBSYSTEM=="tty", ENV{ID_VENDOR_ID}=="2c7c", ENV{ID_MODEL_ID}=="0125", ENV{ID_USB_INTERFACE_NUM}=="02", SYMLINK+="quectel-at"
  '';

  systemd.tmpfiles.rules = [
    "f ${stateDir}/sms.jsonl 0640 asterisk asterisk - -"
  ];

  # SIP and RTP on the LAN interface only
  networking.firewall.interfaces.end0 = {
    allowedUDPPorts = [5060];
    allowedUDPPortRanges = [
      {
        from = 10000;
        to = 10049;
      }
    ];
  };

  # A single line: `password = <letters and digits>`
  age.secrets.asterisk-pjsip-auth = {
    file = "${secrets}/secrets/asterisk-pjsip-auth.age";
    mode = "400";
    owner = "asterisk";
    group = "asterisk";
  };

  # Asterisk's database (SIP registration), SMS database and SMS log
  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = stateDir;
        user = "asterisk";
        group = "asterisk";
        mode = "0750";
      }
    ];
  };
}
