import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders

# Email configuration
sender_email = 'sender@example.com'
receiver_email = 'receiver@example.com'
subject = 'Test Email'
message = 'This is a test email. it should be number 2.'
attachment_path = 'shell_safe.exe'  # Replace with the path to your attachment file

# SMTP server configuration
smtp_server = '172.16.250.135'
smtp_port = 25

# Create a multipart message
msg = MIMEMultipart()
msg['From'] = sender_email
msg['To'] = receiver_email
msg['Subject'] = subject

# Attach the message to the multipart message
msg.attach(MIMEText(message, 'plain'))

# Attach the attachment file
with open(attachment_path, 'rb') as attachment:
    part = MIMEBase('application', 'octet-stream')
    part.set_payload(attachment.read())
    encoders.encode_base64(part)
    part.add_header('Content-Disposition', f'attachment; filename="{attachment_path}"')
    msg.attach(part)

try:
    # Create a SMTP session
    with smtplib.SMTP(smtp_server, smtp_port) as server:
        # Send the email
        server.send_message(msg)

    print('Email sent successfully.')
except smtplib.SMTPException as e:
    print(f'Error: {str(e)}')
