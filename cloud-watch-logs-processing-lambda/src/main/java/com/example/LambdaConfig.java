package com.example;

import com.google.gson.Gson;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;

@Configuration
public class LambdaConfig {

  @Value("${LOGS_TABLE:}")
  private String logsTableName;

  @Bean
  public DynamoDbClient dynamoDbClient() {
    return DynamoDbClient.create();
  }

  @Bean
  public Gson gson() {
    return new Gson();
  }

  @Bean
  public LogsTableClient logsTableClient(DynamoDbClient client) {
    return new LogsTableClient(logsTableName, client);
  }
}
