import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:complaint_system/models/Application.dart';



class EmailService {
  // Replace with your actual SMTP details
  final String _username = Application.smtpUsername;
  final String _password = Application.smtpAppPassword; // Use App Passwords for Gmail

  Future<void> sendStatusEmail(String recipientEmail, String subject, String body) async {
    // Browsers cannot open raw TCP sockets (required by SMTP).
    // On Flutter Web, this would throw: Unsupported operation: Socket constructor.
    if (kIsWeb) {
      debugPrint('EmailService: SMTP email sending is not supported on Flutter Web. Skipping send.');
      return;
    }

    // 1. Configure the SMTP server (Example using Gmail)
    final smtpServer = gmail(_username, _password);

    // 2. Create the message
    final message = Message()
      ..from = Address(_username, 'Civic Connect')
      ..recipients.add(recipientEmail)
      ..subject = subject
      ..text = body;

    try {
      // 3. Send the email
      final sendReport = await send(message, smtpServer);
      print('Message sent: ' + sendReport.toString());
    } on MailerException catch (e) {
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }
}