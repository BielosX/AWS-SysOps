SELECT * FROM cloudtrail_logs_eu_west_1
WHERE
    eventSource = 'sqs.amazonaws.com';