-- Provide a count of customers and the number of engagements they have placed where the contract price is in the top quartile of all contract prices.

--START Q1
select customerid,count(*) as top_quartile_engagements
FROM (select c.customerid,e.contractprice,NTILE(4) OVER (ORDER BY ContractPrice)
FROM engagements e 
JOIN customers c ON c.CustomerID = e.CustomerID) t1
WHERE ntile = 4
GROUP BY customerid
-- END Q1

-- Whenever entertainers in our agency complete their 10th engagement, a blog post is written about the entertainers and the members. We also give their contractprice for the engagement a 10% bonus. 
-- Please list the details of the 10th engagement for each entertainer and the adjusted contracted price. Hint: You’ll need to use a window function and likely filter for row_number = 10 at some point.

--START Q2
select engagementnumber,
entstagename,
round(contractprice*1.1,1) adjusted_contractprice 
FROM (select *,
row_number() over (PARTITION BY en.entertainerid ORDER BY startdate) from engagements en
JOIN entertainers et ON en.entertainerid = et.entertainerid) t1
WHERE row_number = 10
ORDER BY adjusted_contractprice;
--END Q2

-- Show the total revenue generated by our agency after each engagement (use startdate for when the engagement occurs. Note that the revenue generated is not the contract price. It is 10% for all engagements typically. 
-- However, for entertainers who have at least 10 bookings with us, it is 8% of the contract price. 

--START Q3
SELECT *,SUM(agencyrevenue) OVER (ORDER BY startdate,engagementnumber)
FROM (SELECT engagementnumber,startdate,
CASE WHEN num_bookings > 10 THEN contractprice*0.08
ELSE contractprice*0.10 END as agencyrevenue
FROM (SELECT *,COUNT(*) OVER (PARTITION BY et.entertainerid) num_bookings
FROM engagements en
JOIN entertainers et ON en.entertainerid = et.entertainerid) t1
ORDER BY startdate) t2;
--END Q3

-- Produce a report that lists the top five agents and the top five musical styles in terms of number of engagements. 

--START Q4
SELECT type,name,num_engagements
FROM 
(SELECT *
FROM 
(SELECT 'musical_style' as type,stylename as name,num_engagements,1 as ordering FROM
(SELECT DISTINCT stylename,COUNT(*) OVER (PARTITION BY stylename) as num_engagements
FROM musical_styles m
JOIN entertainer_styles es ON m.styleid = es.styleid
JOIN engagements e ON e.entertainerid = es.entertainerid) musical_style_subquery
ORDER BY num_engagements DESC
LIMIT 5) musical_style_subquery_sorted
UNION 
SELECT 'agent' as type,name,num_engagements,2 as ordering
FROM 
(SELECT DISTINCT CONCAT(agtfirstname,' ',agtlastname) as name, 
COUNT(*) OVER (PARTITION BY a.agentid) as num_engagements 
FROM agents a
JOIN engagements e ON a.agentid = e.agentid
ORDER BY num_engagements DESC
LIMIT 5) agents_subquery_sorted
ORDER BY ordering,num_engagements DESC) final_subquery;
--END Q4

-- We use the first two digits after the area code of a phone number to determine if the number is a landline or a mobile phone number. For example, if a phone number is 234-2191, then the type block to consider is 21. 
-- If the type block is greater than 25, it will be a landline phone number. If it is 25 or less, it is a mobile phone number. Classify all agents and customers phone numbers and count the number of landline and mobile numbers.

--START Q5
SELECT DISTINCT phone_types,COUNT(*) OVER (PARTITION BY phone_types) as num_phone_numbers
FROM
(SELECT CASE WHEN type_block >25 THEN 'landline'
ELSE 'mobile' END as phone_types
FROM (SELECT agtphonenumber,
left(right(agtphonenumber,position('-' in agtphonenumber)),2)::INTEGER as type_block
FROM agents
UNION
SELECT custphonenumber,
left(right(custphonenumber,position('-' in custphonenumber)),2)::INTEGER as type_block
FROM customers) union_dataset) union_dataset_with_phone_types;
--END Q5

-- The HR department wants to list out the final compensation for each of the agents. Final compensation is determined by taking their salary and adding it to the commission rate x contractprice for each of their bookings. 
-- For any agent that achieves more than 15 engagement bookings, a final 10% bonus is applied to the total compensation.

--START Q6
SELECT agentid,
salary,
round(commission::numeric,3),
high_performer_bonus,
round(((salary+commission)*(1+high_performer_bonus))::numeric,2) as final_compensation
FROM 
(SELECT agentid,
salary,
commission,
CASE WHEN num_bookings >15 THEN 0.1
ELSE 0 END as high_performer_bonus
FROM (SELECT a.agentid,
salary,
sum(commissionrate*contractprice) as commission, 
salary + sum(commissionrate*contractprice) as base_compensation,
count(*) as num_bookings
FROM agents a
JOIN engagements e ON a.agentid = e.agentid
GROUP BY a.agentid) as base_compensation_per_agent) as high_performer_bonus;
--END Q6