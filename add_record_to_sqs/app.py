import os
import logging
import boto3
import base64
import json
from redis import Redis
import hashlib
import ast


# =============SET ENVIRONMENT VARIABLES=======================
sqs = boto3.client('sqs')
queue_url = os.environ.get('SQS_QUEUE_URL')
is_fifo_queue = os.environ.get('IS_FIFO_QUEUE')
# ==============================================================
data_primary_key = os.environ.get('DATA_PRIMARY_KEY', '')
redis_key = os.environ.get('REDIS_HASH_KEY','')
host=os.environ.get('HOST','')
redis = Redis(host=host, port=6379)
# =============================================================
# =============SET LOGGING=====================================
logger = logging.getLogger()
logger.setLevel(logging.INFO)
logger.info('Loading function')
logger.info("Queue url : " + queue_url)
# =============================================================


def lambda_handler(event: dict, context) -> None:
    """
        Handles the event from the kinesis stream

        Parameters:
            event (dict): The kinesis event
            context: LambdaContext
    """
    
    logger.info(event)
    
    for record in event['Records']:
        dataBase64 = record['kinesis']['data']
        dataJson = base64.b64decode(dataBase64)
        data = json.loads(dataJson)
      
        # if a redis connection has been set then process data accordingly
        if redis.connection_pool.connection_kwargs['host']:
            # redis doesn't like null values so replace them with empty strings
            for key, value in data.items():
                if value is None:
                    data[key] = ''

            # send data to redis
            data_to_redis(payload=data, data_base_64=dataBase64)
        else:
            send_to_sqs(data=data, message_body=json.dumps(data), data_base_64=dataBase64)
    


def data_to_redis(payload: dict, data_base_64: str) -> None:
    """
        Takes in the processed data from the lambda_handler,
        creates a unique hash key of the record which determines whether it
        should be added to the Redis cluster and then sent to the SQS queue
    
        Parameters:
            payload (dict): The veniture license record
            data_base_64 (str): dataBase64 variable from the lambda_handler to be passed to the send_to_sqs function
    """

    hash_key = create_hash_key(key=redis_key, data=payload)
    try:
        if redis.hsetnx('records', hash_key, json.dumps(payload)):
            logger.info(f"New record with hash key '{hash_key}' added to hash 'records'")
            logger.info(f'Sending {payload} to SQS')
            
            # Send record to SQS queue
            message_body = json.dumps(payload)
            send_to_sqs(payload, message_body, data_base_64)
        else:
            logger.info(f"Record with hash key '{hash_key}' already exists in hash 'records'")
    except Exception as e:
        logger.info(f'Problem sending data to the redis cluster / SQS {e}')

def send_to_sqs(data: dict, message_body: str, data_base_64: str) -> None:
    """
        Takes the data proccessed from the lambda_handler and sends it to the SQS queue
    
        Parameters:
            data (dict): The payload to be sent to SQS
            message_body (str): Contents of the payload
            data_base_64 (str): dataBase64 variable from the lambda_handler to be taken as the groupID if data_primary_key is not provided
    """

    if data_primary_key and data_primary_key in data:
        groupId = data[data_primary_key]
    else:
        groupId = data_base_64

    sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=message_body,
            MessageDeduplicationId=data_base_64,
            MessageGroupId=groupId)  


def extract_keys(data:dict, keys: list) -> str:
    """
    Takes in a dict object and a key list.
    Loops through the data extracting the specified key

    Parameters:
        data (dict): The data to be iterated over
        keys (list): List of keys to get required value from data

    Returns:
        The value of the key provided
    """
    
    try:
        if keys:
            extract = data
            for key in keys:
                if key in extract:
                    extract = extract[key]
                else:
                    break     
    except Exception as e:
        logger.error(f'Problem occurred extract_keys: {e}')
    return str(extract)  

def create_hash_key(key: str, data:dict) -> str:
    """
    Takes a specified key from the env vars. Returns a hash based on either this key or the entire record

    Parameters:
        key (str): The key to create a hash on
        data (dict): The record processed from the kinesis stream

    Returns:
        A hash key to define a distinct record to send to redis
    """
    try:
        if key:
            redis_hash_key = ast.literal_eval(redis_key)
            new_key = extract_keys(data, redis_hash_key)
            print(f'key extracted {new_key}')
            hash_key = hashlib.md5(new_key.encode()).hexdigest()
        else:
            hash_key = hashlib.md5(json.dumps(data, sort_keys=True).encode()).hexdigest()
    except Exception as e:
        logger.error(f'Problem occurred create_hash_key: {e}')
    return hash_key











