package com.example.app

import com.timgroup.statsd.NonBlockingStatsDClient
import org.springframework.scheduling.annotation.Scheduled

class MetricsService {
    private val statsd = NonBlockingStatsDClient("", "localhost", 8125)

    @Scheduled(fixedDelay = 10000)
    fun publishCustomMetrics() {
        val maxMemory = Runtime.getRuntime().maxMemory()
        val freeMemory = Runtime.getRuntime().freeMemory()
        val usedMemory = maxMemory - freeMemory
        statsd.recordGaugeValue("JvmMaxMemory", maxMemory)
        statsd.recordGaugeValue("JvmFreeMemory", freeMemory)
        statsd.recordGaugeValue("JvmUsedMemory", usedMemory)
    }
}