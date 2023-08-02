package com.example;

import java.util.Map;
import lombok.RequiredArgsConstructor;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;

@RequiredArgsConstructor
public class LogsTableClient {
  private final String tableName;
  private final DynamoDbClient client;

  public record LogEntry(String id, long timestamp, String message) {}

  public void saveLogEntry(LogEntry entry) {
    PutItemRequest request =
        PutItemRequest.builder()
            .tableName(tableName)
            .item(
                Map.of(
                    "id", AttributeValue.fromS(entry.id()),
                    "timestamp", AttributeValue.fromN(String.valueOf(entry.timestamp())),
                    "message", AttributeValue.fromS(entry.message())))
            .build();
    client.putItem(request);
  }
}
