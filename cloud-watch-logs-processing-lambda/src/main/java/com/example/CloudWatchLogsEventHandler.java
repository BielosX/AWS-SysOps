package com.example;

import com.amazonaws.services.lambda.runtime.events.CloudWatchLogsEvent;
import com.google.gson.Gson;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.zip.GZIPInputStream;
import lombok.RequiredArgsConstructor;
import lombok.SneakyThrows;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class CloudWatchLogsEventHandler {
  private final Gson gson;
  private final LogEventProcessor logEventProcessor;

  @SneakyThrows
  public void handleCloudWatchLogsEvent(CloudWatchLogsEvent event) {
    String encodedData = event.getAwsLogs().getData();
    byte[] decodedData = Base64.getDecoder().decode(encodedData);
    try (GZIPInputStream stream = new GZIPInputStream(new ByteArrayInputStream(decodedData))) {
      String content = new String(stream.readAllBytes(), StandardCharsets.UTF_8);
      LogsMessage message = gson.fromJson(content, LogsMessage.class);
      log.info(
          "Received logs message, log group: {}, log stream: {}",
          message.logGroup(),
          message.logStream());
      message.logEvents().forEach(logEventProcessor::process);
    }
  }
}
