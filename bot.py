import logging
import asyncio
from pyrogram import Client
from pyrogram.errors import FloodWait, RPCError

# Configure logging to capture detailed debug information
logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Telegram API credentials (replace with your own)
API_ID = 10565113  # Replace with your actual api_id (integer)
API_HASH = "d2220b87fb12fc430dc8fcebbb03d95c"  # Replace with your actual api_hash (string)
BOT_TOKEN = "8256526472:AAHyvbxwrK1Z8_CcU9p4Odh6y6twjJKEzhc"  # Replace with your actual bot_token
SESSION_NAME = "my_bot"

# File to upload (replace with your file path)
FILE_PATH = "/home/idies/o/test.mp4"  # Replace with a valid file path
CHAT_ID = "me"  # Use "me" to send to yourself, or replace with a chat ID (e.g., 123456789)

# Retry function for handling uploads with timeouts or rate limits
async def upload_with_retry(client, chat_id, file_path, retries=3, delay=2):
    for attempt in range(retries):
        try:
            logger.info(f"Attempt {attempt + 1}: Uploading file {file_path}")
            await client.send_document(chat_id, file_path)
            logger.info("File uploaded successfully")
            return
        except FloodWait as e:
            logger.warning(f"FloodWait: Waiting for {e.value} seconds")
            await asyncio.sleep(e.value)
        except RPCError as e:
            logger.error(f"Attempt {attempt + 1} failed: {e}")
            if attempt + 1 == retries:
                logger.error("Max retries reached. Upload failed.")
                raise
            await asyncio.sleep(delay)
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            if attempt + 1 == retries:
                raise
            await asyncio.sleep(delay)

async def main():
    # Initialize Pyrogram client without proxy
    async with Client(
        name=SESSION_NAME,
        api_id=API_ID,
        api_hash=API_HASH,
        bot_token=BOT_TOKEN,
        timeout=60  # Increased timeout to handle GetFile issues
    ) as app:
        try:
            # Send a test message to verify connection
            await app.send_message(CHAT_ID, "Bot started successfully!")
            logger.info("Test message sent")

            # Attempt to upload a file
            await upload_with_retry(app, CHAT_ID, FILE_PATH)
        except Exception as e:
            logger.error(f"Main loop error: {e}")

if __name__ == "__main__":
    # Run the bot
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Bot stopped by user")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
