package com.example;

import java.util.List;

public record LogsMessage(
    String messageType,
    String owner,
    String logGroup,
    String logStream,
    List<String> subscriptionFilters,
    List<LogEvent> logEvents) {}
