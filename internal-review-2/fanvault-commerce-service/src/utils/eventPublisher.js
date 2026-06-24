const { EventBridgeClient, PutEventsCommand } = require('@aws-sdk/client-eventbridge');

const eventBridge = new EventBridgeClient({ region: process.env.AWS_REGION || 'us-east-1' });
const BUS_NAME = process.env.EVENTBRIDGE_BUS_NAME || 'fanvault-event-bus';

/**
 * Publishes a domain event to EventBridge.
 * Failures are logged to the console but never thrown to prevent blocking main workflows.
 *
 * @param {string} eventType - The DetailType of the event (e.g., ProductCreated, ProductUpdated, OrderPlaced, InventoryLow)
 * @param {object} detail - The payload of the event
 */
async function publishEvent(eventType, detail) {
  try {
    const params = {
      Entries: [
        {
          Source: 'fanvault.commerce',
          DetailType: eventType,
          Detail: JSON.stringify(detail),
          EventBusName: BUS_NAME,
        },
      ],
    };

    const response = await eventBridge.send(new PutEventsCommand(params));
    console.log(`[EventBridge] Published ${eventType} event. Result:`, response);
    return response;
  } catch (err) {
    console.error(`[EventBridge] Failed to publish ${eventType} event:`, err.message);
  }
}

module.exports = { publishEvent };
