from app.create_order import create_order

def lambda_handler(event, context):
    """
    Lambda function to handle order creation.

    Args:
        event (dict): The event data passed to the Lambda function.
        context (object): The context in which the Lambda function is called.

    Returns:
        dict: A response indicating the result of the order creation process.
    """
    # Extract order details from the event
    order_details = event.get('order_details', {})
    
    # Process the order (this is a placeholder for actual order processing logic)
    order_id = create_order(order_details)
    
    # Return a response with the order ID
    return {
        'statusCode': 200,
        'body': {
            'message': 'Order created successfully',
            'order_id': order_id
        }
    }