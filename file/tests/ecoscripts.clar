import logging
from dataclasses import dataclass
from typing import Dict, Optional
from datetime import datetime
import asyncio
import json

from stacks_sdk import Client, Contract, Account
import paho.mqtt.client as mqtt
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class WasteBin:
    bin_id: int
    location: str
    capacity: float
    current_fill: float
    waste_type: str
    last_emptied: datetime

class IoTManager:
    def __init__(self):
        self.mqtt_client = mqtt.Client()
        self.mqtt_client.on_message = self.on_message
        self.mqtt_client.connect("localhost", 1883, 60)
        self.mqtt_client.subscribe("waste/+/data")
        
        self.influx_client = InfluxDBClient(url="http://localhost:8086", token="your-token", org="ecochain")
        self.write_api = self.influx_client.write_api(write_options=SYNCHRONOUS)
        
        self.bins: Dict[int, WasteBin] = {}
    
    def on_message(self, client, userdata, msg):
        try:
            data = json.loads(msg.payload)
            bin_id = int(msg.topic.split('/')[1])
            
            point = Point("bin_metrics") \
                .tag("bin_id", bin_id) \
                .tag("location", data['location']) \
                .field("fill_level", data['fill_level']) \
                .field("temperature", data.get('temperature', 0))
            
            self.write_api.write(bucket="waste_metrics", record=point)
            
            if bin_id in self.bins:
                self.bins[bin_id].current_fill = data['fill_level']
            
            if data['fill_level'] > 80:
                logger.warning(f"Bin {bin_id} is almost full! Current level: {data['fill_level']}%")
        
        except Exception as e:
            logger.error(f"Error processing IoT data: {e}")

class EcoChainClient:
    def __init__(self, network="testnet"):
        self.client = Client(network)
        self.contract_address = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"
        self.contract_name = "waste-tracking"
        self.iot_manager = IoTManager()
        
    def connect_wallet(self, private_key):
        self.account = Account(private_key)
        logger.info(f"Connected wallet: {self.account.address}")
    
    async def monitor_bins(self):
        while True:
            try:
                self.iot_manager.mqtt_client.loop()
                await asyncio.sleep(1)
            except Exception as e:
                logger.error(f"Error in bin monitoring: {e}")
                await asyncio.sleep(5)
    
    async def record_waste_disposal(self, bin_id: int, amount: float):
        try:
            bin_data = self.iot_manager.bins.get(bin_id)
            if not bin_data:
                raise ValueError(f"Unknown bin ID: {bin_id}")
            
            contract = Contract(self.contract_address, self.contract_name)
            tx = contract.functions['record-waste-disposal'](
                int(amount * 100),  # Convert to integer units
                bin_id,
                bin_data.waste_type
            )
            result = await tx.sign_and_broadcast(self.account)
            logger.info(f"Recorded waste disposal: {result}")
            
            # Update local bin data
            bin_data.current_fill = 0
            bin_data.last_emptied = datetime.now()
            
            return result
        except Exception as e:
            logger.error(f"Error recording waste disposal: {e}")
            raise
    
    async def get_user_stats(self, address: Optional[str] = None):
        try:
            contract = Contract(self.contract_address, self.contract_name)
            target_address = address or self.account.address
            result = await contract.functions['get-user-stats'].call(target_address)
            return result
        except Exception as e:
            logger.error(f"Error getting user stats: {e}")
            raise
    
    async def stake_tokens(self, amount: int):
        try:
            contract = Contract(self.contract_address, self.contract_name)
            tx = contract.functions['stake-tokens'](amount)
            result = await tx.sign_and_broadcast(self.account)
            logger.info(f"Staked {amount} tokens: {result}")
            return result
        except Exception as e:
            logger.error(f"Error staking tokens: {e}")
            raise

async def main():
    client = EcoChainClient()
    
    # Example usage
    private_key = "your-private-key-here"
    client.connect_wallet(private_key)
    
    # Start bin monitoring in the background
    asyncio.create_task(client.monitor_bins())
    
    # Simulate some actions
    try:
        # Stake some tokens
        await client.stake_tokens(1000)
        
        # Record waste disposal
        await client.record_waste_disposal(1, 5.5)  # 5.5 kg of waste
        
        # Get user stats
        stats = await client.get_user_stats()
        logger.info(f"User stats: {stats}")
        
    except Exception as e:
        logger.error(f"Error in main execution: {e}")

if __name__ == "__main__":
    asyncio.run(main())