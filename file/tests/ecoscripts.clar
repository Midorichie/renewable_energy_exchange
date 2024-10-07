from stacks_sdk import Client, Contract, Account
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class EcoChainClient:
    def __init__(self, network="testnet"):
        self.client = Client(network)
        self.contract_address = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"
        self.contract_name = "waste-tracking"
        
    def connect_wallet(self, private_key):
        self.account = Account(private_key)
        logger.info(f"Connected wallet: {self.account.address}")
        
    def record_waste_disposal(self, amount):
        contract = Contract(self.contract_address, self.contract_name)
        tx = contract.functions['record-waste-disposal'](amount)
        result = tx.sign_and_broadcast(self.account)
        return result
    
    def get_user_stats(self, address):
        contract = Contract(self.contract_address, self.contract_name)
        result = contract.functions['get-user-stats'].call(address)
        return result
    
    def get_total_waste_tracked(self):
        contract = Contract(self.contract_address, self.contract_name)
        result = contract.functions['get-total-waste-tracked'].call()
        return result

def main():
    client = EcoChainClient()
    
    # Example usage
    private_key = "your-private-key-here"
    client.connect_wallet(private_key)
    
    # Record waste disposal
    result = client.record_waste_disposal(100)
    logger.info(f"Recorded waste disposal: {result}")
    
    # Get user stats
    stats = client.get_user_stats(client.account.address)
    logger.info(f"User stats: {stats}")
    
    # Get total waste tracked
    total = client.get_total_waste_tracked()
    logger.info(f"Total waste tracked: {total}")

if __name__ == "__main__":
    main()