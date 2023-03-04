package com.example.app

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.scheduling.annotation.EnableScheduling

@Configuration
@EnableScheduling
class MetricsConfiguration {

    @Bean
    fun metricsService(): MetricsService {
        return MetricsService()
    }
}