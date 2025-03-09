# PubSub Enhancement Migration Guide

This document outlines the steps for migrating to the enhanced PubSub system for event handling in the GameBot application.

## Overview

The enhanced PubSub system provides more granular control over event subscriptions, allowing components to subscribe to specific event types across games. This reduces unnecessary message processing and improves system modularity.

## Migration Steps

### Phase 1: Testing in Development

1. **Review Implementation**
   - Verify all components are implemented correctly
   - Run the test suite to ensure all tests pass: `mix test`

2. **Test in Development**
   - Enable the enhanced PubSub in development:
     ```elixir
     # In config/dev.exs
     config :game_bot, :event_system,
       use_enhanced_pubsub: true
     ```
   - Run the application and verify event handling works correctly
   - Monitor logs for any errors or issues

### Phase 2: Controlled Migration in Staging

1. **Update Staging Configuration**
   - Enable the enhanced PubSub in staging:
     ```elixir
     # In config/staging.exs (if it exists)
     config :game_bot, :event_system,
       use_enhanced_pubsub: true
     ```

2. **Create Monitoring Dashboards**
   - Set up telemetry dashboards to monitor:
     - Event broadcast metrics (duration, topic counts)
     - Error rates in event handling
     - Event processing latency

3. **Validate Performance**
   - Run load tests to verify system performance
   - Ensure event handling works correctly under load
   - Verify there are no unexpected errors or bottlenecks

### Phase 3: Production Deployment

1. **Enable Feature Flag in Production**
   - Update production configuration:
     ```elixir
     # In config/prod.exs
     config :game_bot, :event_system,
       use_enhanced_pubsub: true
     ```

2. **Monitor Production Deployment**
   - Closely monitor the application after deployment
   - Watch for any unexpected behavior or errors
   - Be prepared to disable the feature flag if issues arise

3. **Verify Production Performance**
   - Review telemetry metrics to ensure system is performing as expected
   - Compare performance against baseline measurements

## Rollback Procedure

If issues are detected with the enhanced PubSub system:

1. **Disable Feature Flag**
   - Set the feature flag to false:
     ```elixir
     # In the appropriate config file
     config :game_bot, :event_system,
       use_enhanced_pubsub: false
     ```

2. **Deploy Configuration Change**
   - Deploy the configuration change to revert to the legacy behavior
   - No code changes are required for rollback

3. **Post-Rollback Analysis**
   - Investigate the issues that led to the rollback
   - Develop a plan to address the issues before attempting re-deployment

## Adopting the Handler Behavior

For teams creating new event handlers, we recommend migrating to the `GameBot.Domain.Events.Handler` behavior:

1. **Identify Existing Handlers**
   - Find all modules that currently handle events from PubSub

2. **Create New Handlers with the Behavior**
   - For each existing handler, create a new version using the behavior:
     ```elixir
     defmodule MyApp.NewHandler do
       use GameBot.Domain.Events.Handler,
         interests: ["event_type:example_event"]
         
       @impl true
       def handle_event(event) do
         # Handle the event
         :ok
       end
     end
     ```

3. **Add New Handlers to Supervision Tree**
   - Add the new handlers to your application's supervision tree
   - Test to ensure they receive and process events correctly

4. **Remove Old Handlers**
   - Once the new handlers are working correctly, remove the old ones
   - Unsubscribe from any manual subscriptions in the old handlers

## Troubleshooting

### Common Issues

1. **Events Not Being Received**
   - Check if the handler is correctly registered in the supervision tree
   - Verify the interests list includes the correct topics
   - Ensure the handler's `handle_event/1` function matches the expected event structure

2. **Duplicate Event Handling**
   - Check if a handler is subscribed to both game-specific and event-type topics for the same events
   - Implement deduplication logic using event IDs if necessary

3. **Handler Crashes Repeatedly**
   - Check for unhandled exceptions in the `handle_event/1` function
   - Ensure pattern matching is exhaustive for all event types

### Getting Help

If you encounter issues during migration, please:

1. Check the test suite for examples of correct usage
2. Review the documentation in `lib/docs/domain/events/pubsub_usage_guide.md`
3. Contact the core team for assistance

## Future Development

After successful migration, we'll consider implementing additional features:

1. **Handler Supervisor**
   - Centralized supervision for event handlers
   - Automatic registration of handlers

2. **Additional Topic Patterns**
   - Guild-specific subscriptions
   - Player-specific subscriptions

3. **Event Transformation**
   - Transform events for specific consumers before delivery 