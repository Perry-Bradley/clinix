from celery import shared_task
from .federated_aggregator import FederatedAggregator

@shared_task
def run_federated_aggregation():
    aggregator = FederatedAggregator(min_updates=10) # 10 for demo/testing
    success, message = aggregator.aggregate_weights()
    return message
