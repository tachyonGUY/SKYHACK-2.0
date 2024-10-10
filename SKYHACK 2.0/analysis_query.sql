-- 1. *What are the average and distribution of Average Handle Time (AHT) and Average Speed to Answer (AST)?--->Distribution (Bucketing): Shows the spread of times in different intervals.

SELECT 
    AVG(EXTRACT(EPOCH FROM (call_end_datetime - agent_assigned_datetime))) AS "avg_handle_time(sec)", 
    AVG(EXTRACT(EPOCH FROM (agent_assigned_datetime - call_start_datetime))) AS "avg_speed_to_answer(sec)" 
FROM 
    calls;
------------------------------------------------------------------------------------------------------------
SELECT 
    CASE
        WHEN EXTRACT(EPOCH FROM (call_end_datetime - agent_assigned_datetime)) / 60 <= 2 THEN '0-2 minutes'
        WHEN EXTRACT(EPOCH FROM (call_end_datetime - agent_assigned_datetime)) / 60 > 2 AND EXTRACT(EPOCH FROM (call_end_datetime - agent_assigned_datetime)) / 60 <= 5 THEN '2-5 minutes'
        WHEN EXTRACT(EPOCH FROM (call_end_datetime - agent_assigned_datetime)) / 60 > 5 AND EXTRACT(EPOCH FROM (call_end_datetime - agent_assigned_datetime)) / 60 <= 10 THEN '5-10 minutes'
        ELSE '>10 minutes'
    END AS AHT_range,
    COUNT(*) AS call_count
FROM 
    calls
GROUP BY AHT_range
ORDER BY call_count DESC;

-- Repeat for AST
SELECT 
    CASE
        WHEN EXTRACT(EPOCH FROM (agent_assigned_datetime - call_start_datetime)) / 60 <= 1 THEN '0-1 minute'
        WHEN EXTRACT(EPOCH FROM (agent_assigned_datetime - call_start_datetime)) / 60 > 1 AND EXTRACT(EPOCH FROM (agent_assigned_datetime - call_start_datetime)) / 60 <= 3 THEN '1-3 minutes'
        WHEN EXTRACT(EPOCH FROM (agent_assigned_datetime - call_start_datetime)) / 60 > 3 AND EXTRACT(EPOCH FROM (agent_assigned_datetime - call_start_datetime)) / 60 <= 5 THEN '3-5 minutes'
        ELSE '>5 minutes'
    END AS AST_range,
    COUNT(*) AS call_count
FROM 
    calls
GROUP BY AST_range
ORDER BY call_count DESC;




-- 2. *Which agents handle calls more efficiently (shorter Average Handle Time (AHT))?

   select agent_id,
   COUNT(*) AS call_attended,
   ROUND(AVG(EXTRACT(EPOCH FROM (call_end_datetime - agent_assigned_datetime))),2) AS "avg_handle_time(sec)",
   ROUND(AVG(EXTRACT(EPOCH FROM (agent_assigned_datetime - call_start_datetime))),2) AS "avg_speed_to_answer(sec)" 
   from calls 
   group by agent_id
   order by call_attended desc,"avg_speed_to_answer(sec)","avg_handle_time(sec)"



-- 3. *What are the most common reasons for calls, and how do they affect AHT?*

WITH AHT_per_reason AS (
    SELECT 
        r.primary_call_reason,
        COUNT(*) AS call_count,
        AVG(EXTRACT(EPOCH FROM (c.call_end_datetime - c.agent_assigned_datetime))) AS avg_AHT_seconds
    FROM 
        calls c
    LEFT JOIN 
        reason r ON r.call_id = c.call_id
    GROUP BY 
        r.primary_call_reason
),
Overall_AHT AS (
    select AVG(EXTRACT(EPOCH FROM (call_end_datetime - agent_assigned_datetime))) as overall_AHT from calls
)
SELECT 
    a.primary_call_reason as reason,
	a.call_count as "Frequency",
    ROUND(a.avg_AHT_seconds,2) as "AHT_per_reason(sec)",
    ROUND(o.overall_AHT,2) as Overall_AHT,
    ROUND((a.avg_AHT_seconds - o.overall_AHT),2) AS impact_on_AHT
FROM 
    AHT_per_reason a,
    Overall_AHT o
ORDER BY "Frequency" DESC, impact_on_AHT DESC

-- Identifying Key Drivers:

-- If you find that certain common reasons (e.g., "Flight Cancellation") have a significantly higher AHT than the overall AHT, those are likely key drivers contributing to increased AHT.
-- Conversely, if a reason with high call volume has a lower AHT, it might be managed efficiently.




-- 4. *How does customer loyalty level impact call behavior?*


-- loyalty levels can indicate:
-- 0: Non-loyal customers
-- 1: Low loyalty
-- 2: Medium loyalty
-- 3: High loyalty
-- 4, 5: Elite or other specific categories

WITH Loyalty_Call_Metrics AS (
    SELECT 
        cus.elite_level_code AS loyalty_level,
        COUNT(c.call_id) AS total_calls,
        AVG(EXTRACT(EPOCH FROM (c.call_end_datetime - c.agent_assigned_datetime))) AS avg_AHT_seconds,
        AVG(EXTRACT(EPOCH FROM (c.agent_assigned_datetime - c.call_start_datetime))) AS avg_AST_seconds,
        AVG(s.average_sentiment) AS avg_sentiment
    FROM 
        calls c
    LEFT JOIN 
        customer cus ON c.customer_id = cus.customer_id
    LEFT JOIN 
        sentiment_stats s ON s.call_id = c.call_id
    GROUP BY 
        cus.elite_level_code
)
SELECT 
    loyalty_level,
    total_calls,
    ROUND(avg_AHT_seconds, 2) AS avg_AHT_seconds,
    ROUND(avg_AST_seconds, 2) AS avg_AST_seconds,
    ROUND(avg_sentiment*100, 4) AS avg_sentiment
FROM 
    Loyalty_Call_Metrics
ORDER BY 
    loyalty_level;




-- 5. *How does sentiment (agent/customer tone) and silence during calls impact call duration?*

WITH Call_Duration AS (
    SELECT 
        s.agent_tone,
        s.customer_tone,
        s.silence_percent_average,
        EXTRACT(EPOCH FROM (c.call_end_datetime - c.agent_assigned_datetime)) AS AHT_seconds
    FROM 
        calls c
    LEFT JOIN 
        sentiment_stats s ON s.call_id = c.call_id
)
SELECT 
    agent_tone,
    customer_tone,
    ROUND(AVG(silence_percent_average), 2) AS avg_silence_percent,
    COUNT(*) AS call_count,
    ROUND(AVG(AHT_seconds), 2) AS avg_AHT_seconds
FROM 
    Call_Duration
GROUP BY 
    agent_tone, customer_tone
ORDER BY 
    avg_AHT_seconds DESC;



-- 6. *When do customers tend to experience higher AST?*
----------------------Weekly Analysis---------------------------------------------------------
WITH AST_per_Call AS (
    SELECT 
        EXTRACT(EPOCH FROM (c.agent_assigned_datetime - c.call_start_datetime)) AS AST_seconds,
        CASE 
            WHEN EXTRACT(DOW FROM c.call_start_datetime) = 0 THEN 'Sunday'
            WHEN EXTRACT(DOW FROM c.call_start_datetime) = 1 THEN 'Monday'
            WHEN EXTRACT(DOW FROM c.call_start_datetime) = 2 THEN 'Tuesday'
            WHEN EXTRACT(DOW FROM c.call_start_datetime) = 3 THEN 'Wednesday'
            WHEN EXTRACT(DOW FROM c.call_start_datetime) = 4 THEN 'Thursday'
            WHEN EXTRACT(DOW FROM c.call_start_datetime) = 5 THEN 'Friday'
            WHEN EXTRACT(DOW FROM c.call_start_datetime) = 6 THEN 'Saturday'
        END AS day_of_week
    FROM 
        calls c
)
SELECT 
    day_of_week,
    COUNT(*) AS total_calls,
    ROUND(AVG(AST_seconds), 2) AS avg_AST_seconds
FROM 
    AST_per_Call
GROUP BY 
    day_of_week
ORDER BY 
    CASE 
        WHEN day_of_week = 'Sunday' THEN 1
        WHEN day_of_week = 'Monday' THEN 2
        WHEN day_of_week = 'Tuesday' THEN 3
        WHEN day_of_week = 'Wednesday' THEN 4
        WHEN day_of_week = 'Thursday' THEN 5
        WHEN day_of_week = 'Friday' THEN 6
        WHEN day_of_week = 'Saturday' THEN 7
    END;



