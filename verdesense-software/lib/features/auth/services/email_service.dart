import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  static Future<void> sendWelcomeEmail({
    required String targetEmail,
    required String name,
    required String username,
    required String tempPassword,
    required String role,
  }) async {
    final senderEmail = dotenv.env['SMTP_EMAIL'];
    final appPassword = dotenv.env['SMTP_PASSWORD'];

    // If not configured, just return early entirely or throw error
    if (senderEmail == null || senderEmail.isEmpty || appPassword == null || appPassword.isEmpty) {
      throw Exception('SMTP Configuration Missing: Unable to load credentials from .env. Received: Email (\$senderEmail), Pass (\$appPassword)');
    }

    final smtpServer = gmail(senderEmail, appPassword);

    final String htmlTemplate = '''
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0d1017; margin: 0; padding: 20px; color: #ffffff; }
        .container { max-width: 600px; margin: 0 auto; background-color: #222838; border-radius: 12px; overflow: hidden; box-shadow: 0 8px 24px rgba(0,0,0,0.5); border: 1px solid rgba(255,255,255,0.05); }
        .header { background-color: #11141D; color: #ffffff; padding: 32px 24px; text-align: center; } 
        .header h1 { margin: 0; font-size: 26px; font-weight: 700; letter-spacing: -0.5px; }
        .header h1 span { color: #EF4444; } 
        .header p { margin: 10px 0 0; font-size: 14px; opacity: 0.8; font-weight: 500; }
        .content { padding: 40px; background-color: #222838; } 
        .greeting { font-size: 16px; margin-bottom: 24px; line-height: 1.6; color: #ffffff; }
        .credentials-box { border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; padding: 28px; background-color: #11141D; margin-bottom: 24px; }
        .label { color: #9CA3AF; font-weight: 500; font-size: 14px; }
        .val { font-weight: 600; color: #ffffff; font-size: 15px; }
        .temp-pass-pill { background-color: rgba(30, 58, 138, 0.4); border: 1px solid rgba(59, 130, 246, 0.3); border-radius: 6px; padding: 8px 14px; display: inline-block; font-family: 'Courier New', Courier, monospace; font-size: 16px; font-weight: 700; color: #93C5FD; letter-spacing: 1px; }
        .warning-box { background-color: rgba(245, 158, 11, 0.1); border: 1px solid #F59E0B; border-radius: 8px; padding: 16px; margin-bottom: 24px; }
        .warning-title { color: #F59E0B; font-weight: bold; margin-bottom: 4px; display: flex; align-items: center; }
        .warning-title span { margin-left: 6px; }
        .warning-text { color: #F59E0B; font-size: 13px; margin: 0; }
        .footer { padding: 24px; text-align: center; font-size: 12px; color: #9CA3AF; border-top: 1px solid rgba(255,255,255,0.05); background-color: #11141D; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Welcome to Crowd<span>Sense</span></h1>
            <p>Intelligent Crowd Monitoring & Alert System</p>
        </div>
        <div class="content">
            <div class="greeting">
                Hello <strong>$name</strong>,<br><br>
                Your account has been created successfully. Please use the temporary credentials below to access the system:
            </div>
            
            <div class="credentials-box">
                <table width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse: collapse;">
                    <tr>
                        <td width="160" class="label" style="padding-bottom: 20px;">Username</td>
                        <td class="val" style="padding-bottom: 20px;">$username</td>
                    </tr>
                    <tr>
                        <td width="160" class="label" style="padding-bottom: 20px;">Temporary Password</td>
                        <td class="val" style="padding-bottom: 20px;">
                            <div class="temp-pass-pill" title="Double-click to highlight">$tempPassword</div>
                        </td>
                    </tr>
                    <tr>
                        <td width="160" class="label">Access Level</td>
                        <td class="val" style="text-transform: capitalize;">$role</td>
                    </tr>
                </table>
            </div>
 
            <div class="warning-box">
                <div class="warning-title">⚠️ <span>Important Security Note</span></div>
                <p class="warning-text">For your protection, you will be required to change this temporary password immediately upon your first login.</p>
            </div>
        </div>
        <div class="footer">
            This is an automated message from the CrowdSense App. Please do not reply.<br>
            <span style="opacity: 0.3; font-size: 10px;">Ref: ${DateTime.now().millisecondsSinceEpoch}</span>
        </div>
    </div>
</body>
</html>
    ''';

    final message = Message()
      ..from = Address(senderEmail, 'CrowdSense App')
      ..recipients.add(targetEmail)
      ..subject = 'Welcome to CrowdSense - Your Account Details'
      ..html = htmlTemplate;

    try {
      await send(message, smtpServer);
      debugPrint('SMTP Email sent successfully to $targetEmail');
    } catch (e) {
      debugPrint('Failed to send SMTP email: $e');
      throw Exception('Failed to email temporary password.');
    }
  }
}
