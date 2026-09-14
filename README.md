# QRZ-Helper---Public


QRZ CONFIRMATION EMAIL HELPER
Created by Thomas Bernard - ZL3TOM
https://zl3tom.com

PURPOSE
=======
This Windows helper assists amateur radio operators with outstanding QRZ
Logbook confirmation requests when they know the callsign and QSO date but
need the other operator to provide the original UTC time, band/frequency,
and mode from their own log.

It does NOT guess QSO details and it does NOT bypass QRZ's confirmation rules.

REQUIREMENTS
============
- Windows with Windows PowerShell 5.1
- Internet access
- QRZ account
- QRZ subscription with XML Logbook Data access for full lookup data
- An email provider/account that permits authenticated SMTP access

FIRST LAUNCH
============
Double-click:

  RUN_ME.bat

On first launch only, a setup wizard asks for:

- your name
- your primary callsign
- your location
- optional website
- email provider
- SMTP login
- From email address
- From display name
- SMTP/app password

Preset providers:
- Gmail / Google Workspace
- Outlook.com / Hotmail / Live
- Microsoft 365
- Yahoo Mail
- AOL Mail
- Fastmail
- Apple iCloud Mail
- Zoho Mail
- Manual / Other SMTP provider

IMPORTANT:
Provider policies change. The presets are conveniences, not a guarantee
that password-based SMTP is enabled on a particular account.

TEST BEFORE SAVE
================
The setup is NOT saved immediately.

The helper first sends a test email to an address you choose.

If the test succeeds:
- the setup is saved
- your password/app password is stored using Windows user-specific encryption
- future runs reuse your email setup

If the test fails:
- nothing is saved
- the error is shown
- you can run email setup again

The saved encrypted password is intended to be usable only by the same
Windows user account on the same computer.

QRZ LOGIN
=========
QRZ login information is NEVER saved.

Every normal run begins with:

  QRZ XML Subscription Required

and then takes you to:

  QRZ Login

You must enter your QRZ username/callsign and QRZ password each time.

GETTING QRZ REQUESTS INTO THE HELPER
====================================
Edit:

  incoming_qrz_requests.csv

It contains three columns:

  their_callsign,qso_date,my_callsign

Example:

  their_callsign,qso_date,my_callsign
  W1ABC,2026-09-01,N0CALL
  VK2XYZ,2026-09-02,N0CALL
  W1ABC,2026-09-05,N0CALL
  G0ABC,2024-04-10,N0ALT

WHAT THE COLUMNS MEAN
=====================
their_callsign
  The callsign of the operator who sent the QRZ confirmation request.

qso_date
  The QSO date shown in QRZ.
  It MUST be YYYY-MM-DD.
  Example: 14 September 2026 becomes 2026-09-14.

my_callsign
  YOUR callsign that was used for that QSO.
  This is especially important if you have more than one callsign.

You may add as many rows as needed.

If the same operator has several request dates using the same one of your
callsigns, the helper groups those dates into one email.

HOW TO COLLECT THE DATA
=======================
Open your QRZ Logbook confirmation-request area and, for each outstanding
request, record:

1. the other station's callsign
2. the QSO date displayed by QRZ
3. your callsign used for that QSO

Enter one QSO request per row in incoming_qrz_requests.csv.

The helper does not need you to know the missing UTC time, band/frequency,
or mode. Asking the other operator for those original-log details is the
purpose of the generated email.

DUPLICATE / SENT MEMORY
=======================
Successful sends are remembered in:

  sent_history.csv

Each QSO is remembered using:

  your callsign + their callsign + QSO date

Example:

  N0CALL|W1ABC|2026-09-01

If that exact request is entered again later, it is skipped.

If the same station sends another request for a NEW date, the new date is
still processed.

FAILED emails are not treated as successfully sent and may be retried.

QRZ LOOKUP
==========
The helper uses QRZ XML data to retrieve available operator information,
including the name and public email address when returned for the account.

If no email address is returned, the helper does not send an email to that
operator.

EMAIL SAFETY
============
Nothing is sent immediately.

For every available recipient, the helper shows:

- recipient email
- operator name and callsign
- their callsign
- your callsign for the QSO
- dates
- subject
- complete message

You choose:

  A = Approve
  S = Skip
  Q = Stop reviewing

After that, the helper gives one final summary.

You must type:

  SEND

exactly before approved emails are transmitted.

EMAIL PROVIDER NOTES
====================
Gmail / Google Workspace:
  Google may require a 16-digit App Password for programs that do not
  support Sign in with Google. App Passwords require 2-Step Verification
  and may not be available on all managed accounts.

Yahoo:
  Yahoo provides third-party app passwords from Account Security.

Fastmail:
  Create an app password in:
  Settings > Privacy & Security > Connected apps & API tokens >
  Manage app passwords and access > New app password.
  Fastmail Basic does not include SMTP access.

Apple iCloud:
  Third-party SMTP normally uses an Apple app-specific password.
  SMTP server: smtp.mail.me.com, port 587.

Microsoft:
  Microsoft account/organisation security policies can block password-based
  SMTP even when the server/port are correct. Microsoft 365 administrators
  may need to allow SMTP AUTH.

Manual / Other:
  Choose this if your provider is not listed or uses different settings.
  Enter the SMTP host, port and TLS setting provided by your email service.

RESETTING EMAIL / STATION SETUP
===============================
Run:

  RESET_SETUP.bat

This removes helper_config.xml so the first-launch wizard runs again.

It deliberately does NOT delete sent_history.csv.

ERRORS
======
If the helper crashes, the launcher remains open and technical details are
written to:

  error_log.txt

SHARING / CREDIT
================
This utility was created by:

Thomas Bernard - ZL3TOM
Christchurch, New Zealand
https://zl3tom.com

You may share the ZIP with other amateur radio operators. Users should
configure their own callsign, station information and email credentials.

DISCLAIMER
==========
This is an independent amateur-radio utility and is not an official QRZ,
Google, Microsoft, Yahoo, Fastmail, Apple, AOL or Zoho product.

SMTP provider settings and authentication policies can change. Users should
check their provider's current documentation if a preset stops working.
