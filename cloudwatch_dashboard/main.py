import random
import logging

def handler(event, context):
    value = random.randrange(1, 11)
    if value > 7:
        logging.error("Some error")
    else:
        logging.info("Everything is fine")
    return "OK"