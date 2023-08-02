package com.example;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.CloudWatchLogsEvent;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ApplicationContext;

@SpringBootApplication
public class LogsHandler implements RequestHandler<CloudWatchLogsEvent, Void> {

  @Override
  public Void handleRequest(CloudWatchLogsEvent input, Context context) {
    ApplicationContext appContext = SpringApplication.run(LogsHandler.class);
    CloudWatchLogsEventHandler handler = appContext.getBean(CloudWatchLogsEventHandler.class);
    handler.handleCloudWatchLogsEvent(input);
    return null;
  }
}
