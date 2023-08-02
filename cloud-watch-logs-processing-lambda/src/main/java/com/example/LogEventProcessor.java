package com.example;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class LogEventProcessor {
  private final LogsTableClient client;

  public void process(LogEvent event) {
    LocalDateTime timestamp =
        LocalDateTime.ofInstant(Instant.ofEpochMilli(event.timestamp()), ZoneOffset.UTC);
    log.info("Processing log event with id {}, timestamp {}", event.id(), timestamp);
    LogsTableClient.LogEntry entry =
        new LogsTableClient.LogEntry(event.id(), event.timestamp(), event.message());
    client.saveLogEntry(entry);
  }
}
