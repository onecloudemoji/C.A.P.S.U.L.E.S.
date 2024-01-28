#THIS GETS RUN ON THE WINDOWS MACHINE

import asyncio
import os
from aiosmtpd.controller import Controller
from email.parser import BytesParser
from email.policy import default

class CustomSMTPHandler:
    async def handle_RCPT(self, server, session, envelope, address, rcpt_options):
        envelope.rcpt_tos.append(address)
        return '250 OK'

    async def handle_DATA(self, server, session, envelope):
        msg = envelope.content.decode('utf-8')
        parser = BytesParser(policy=default)
        parsed_msg = parser.parsebytes(msg.encode())

        # Define the directory where attachments will be saved
        upload_dir = "c:\\users\\administrator\\desktop\\upload"

        # Create the directory if it doesn't exist
        if not os.path.exists(upload_dir):
            os.makedirs(upload_dir)

        # Save attachments
        for part in parsed_msg.iter_parts():
            if part.get_filename():
                filename = part.get_filename()
                # Join the upload directory with the filename to create the full path
                full_path = os.path.join(upload_dir, filename)
                with open(full_path, 'wb') as f:
                    f.write(part.get_payload(decode=True))
                print(f"Saved attachment: {full_path}")

        return '250 OK'

# Set the server address and port
server_address = ''
server_port = 25

# Create an instance of the CustomSMTPHandler
handler = CustomSMTPHandler()

# Create and start the controller
controller = Controller(handler, hostname=server_address, port=server_port)
controller.start()

try:
    # Run the event loop
    asyncio.get_event_loop().run_forever()
except KeyboardInterrupt:
    # Stop the controller and close the event loop
    controller.stop()
