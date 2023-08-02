package com.example;

import com.google.gson.Gson;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;

@Configuration
public class LambdaConfig {

  @Bean
  public DynamoDbClient dynamoDbClient() {
    return DynamoDbClient.create();
  }

  public Gson gson() {
    return new Gson();
  }
}
