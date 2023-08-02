package com.example;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class LogEventProcessor {

  public void process(LogEvent event) {
    LocalDateTime timestamp =
        LocalDateTime.ofInstant(Instant.ofEpochMilli(event.timestamp()), ZoneOffset.UTC);
    log.info("Processing log event with id {}, timestamp {}", event.id(), timestamp);
  }
}
