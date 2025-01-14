# This first half will be data cleaning oriented and the 2nd half will be more focused on exploration

# Loading the table to get an idea of what is inside and also to look for dirty data that needs to be cleaned up
SELECT * 
FROM world_life_expectancy.world_life_expectancy;

/* Based off of some initial viewing, there seems to be some missing details in the status and life expectancy columns.
There could also be duplicates throughout the data, which I'll look for first and then worry about populating the missing cells.
After looking at the data, we can infer that we should only have copy of each country for every year. So there shouldn't be 2 
United States with the same year for example. We can use this to check for duplicates*/

Select Country, Year, COUNT(concat(Country, Year)) as num_of_copies
From world_life_expectancy
GROUP BY Country, Year, CONCAT(Country, Year)
HAVING COUNT(CONCAT(Country, Year)) > 1;

/*I'll explain what I'm doing above. Because there should only be one copy of each country and year combination, I concatinate
the two to make one unique piece of data for each country/year and then group it all so that I can see if there is more than
one copy of each newly created combination. I then use HAVING clause to filter the data so I can easily find any duplicates.
Now that I've determined there are indeed duplicates, I need to remove them from the table. Thankfully each row has a unique 
row id that can be used to specifically target the duplicate rows and remove them.*/

/*Now you could go and find each individual duplciate row and then manually delete them, this wouldn't take that much time
given that there are only 3 duplicates. But this isn't practical in actual data cleaning because there could by hundreds or
even thousands of duplicates that would need to be removed. Which makes manual removal not feesable. Instead we can partition 
the data based on the concatenation that we used to filter the data earlier and use Row_Number to perform the same task as our
having clause did in the previous query. We're not finished quite yet though, now that we've gotten our Row_ID included in our
table view, we need a way to filter the data to only show rows with more than one row_num.*/

SELECT  Row_ID, CONCAT(Country, Year),
ROW_NUMBER() OVER(PARTITION BY CONCAT(Country, Year) ORDER BY CONCAT(Country, Year)) as Row_Num
FROM world_life_expectancy
;

/*I'll use a subquery in the from clause so that we can filter our data like we want. We need a subquery because of the way 
each statement are initiated in SQL. The select statement is not performed first, despite being written first. The order of
execution is FROM -> WHERE -> GROUP BY -> HAVING -> SELECT. As you can see, the where statement would execute before the 
select statement. And becuase the Row_num column hadn't been created yet in our query, it wouldn't be able to filter off of it. 
Because of this, we just use a sub-query to filter off of the data after it's already been created.*/

SELECT *
FROM(
	SELECT  Row_ID, CONCAT(Country, Year),
	ROW_NUMBER() OVER(PARTITION BY CONCAT(Country, Year) ORDER BY CONCAT(Country, Year)) as Row_Num
	FROM world_life_expectancy) as Row_Table
WHERE Row_Num > 1
;

/*We can now delete all of the duplicate rows at once using the query that we wrote above. Never do this without making a backup of the data because we do not want to delete information from our raw data unless we're certain it is necessary*/

DELETE FROM world_life_expectancy
WHERE 
	Row_ID IN (
	SELECT Row_ID
	FROM(
	SELECT  Row_ID, CONCAT(Country, Year),
	ROW_NUMBER() OVER(PARTITION BY CONCAT(Country, Year) ORDER BY CONCAT(Country, Year)) as Row_Num
	FROM world_life_expectancy) as Row_Table
WHERE Row_Num > 1)
;
/*Running the subquery again should now return no output. Now that there duplcates have been removed, we can focus on populating the empty cells. First we'll work on populating the rows that are missing a Status as that should be relatively easy to populate.*/

SELECT *
FROM world_life_expectancy
WHERE Status = ''
;

/*We can first check for all of the varying statuses so we know what to populate for each country*/

SELECT DISTINCT(Status)
FROM world_life_expectancy
WHERE Status != ''
;

/*Because we now know that the only two statuses are Developing or Developed, we can populate the missing data when the specific countries has a populated status in another year.*/

SELECT DISTINCT(Country)
FROM world_life_expectancy
WHERE Status = 'Developing'
;

/*This is the update query for all countries that have a 'Developing' status in the status column. We are telling SQL to update a country's status to 'Developing' ONLY if that country exists in the query where a country status is listed as developing.*/

UPDATE world_life_expectancy
SET Status = 'Developing'
WHERE Country IN( 	SELECT DISTINCT(Country)
					FROM world_life_expectancy
					WHERE Status = 'Developing');
                    
/*You thought that would work didn't you? I know I did when going through this project at first. We can't update a table when it is referencing that same table in your subquery, because it won't know if it should use the original data or the updated data for the filtering in the WHERE clause.  There are a few ways to get around this like using a temp table to populate the data we will be changing the original to and then updating the original table with the temp table. But I'll be using a self join instead. The self join works because it allows us to separate the reading and writing operations since they are used with "different" tables, thus removing the ambiguity.*/

/*I'll briefly explain what the following code is doing. It is updating the world life expectancy table, specifically the Status column. But it's only going to update it when the row is blank ' ' AND where it isn't blank in the other version of that table while the row also contains 'Developing'. This sounds a bit confusing and honestly it kind of is. We're basically reading data from the t2 version of the table and then writing it to the t1 version of it.  */

UPDATE world_life_expectancy t1
JOIN world_life_expectancy t2
	ON t1.Country = t2.Country
SET t1.Status = 'Developing'
WHERE t1.Status = '' 
AND t2.Status <> ''
AND t2.Status = 'Developing'
;

/* Now let's go back and check to see if we have any countries with an empty status*/

SELECT *
FROM world_life_expectancy
WHERE Status = ''
;

/*Seems like we have one left over. The reason that our update query didn't affect that particular row is that the United States is marked as a 'Developed' Country. So we just need to use our update query again, but change the status to 'Developed' instead of 'Developing'*/

UPDATE world_life_expectancy t1
JOIN world_life_expectancy t2
	ON t1.Country = t2.Country
SET t1.Status = 'Developed'
WHERE t1.Status = '' 
AND t2.Status <> ''
AND t2.Status = 'Developed'
;

/*Searching again for blank statuses returns zero rows, so we've successfully populated that particular column*/

/* If you recall from earlier, we were also missing data in another column, the Life expectancy column. Let's find out how many rows are missing data there.*/

/*It seems like there's only 2 missing cells in this column. Now it's not really a bad thing to have an empty space here, whether or not to populate a cell often times depends on a number of factors like how many cells will be affected, is there anyway to populate them somewhat reliably, will we be using the column for data exploration etc.
In this case since it's only two cells, it won't have much of an impact on the data set, plus we may want to do analysis on the life expectancy column, so it would be nice if it was populated. */
SELECT * 
FROM world_life_expectancy
WHERE `Life expectancy` = ''
;

SELECT * 
FROM world_life_expectancy
WHERE Country = 'Afghanistan' OR Country = 'Albania'
;
/*In both cases, we can see that the life expectancy is slowly increasing as the years go on. So we can use an avg of the following and previous year surrounding our missing years as a usable placeholder for when we do our data exploration later. In both cases, the year that is missing is the year 2018. So we can do self joins with this table to display the past and following year. Then we take the life expectancy for each of the two years and find the avg of the two. This gives us the number that we can use to populate our missing data. Lastly we filter the data in the where clause to only show us the data for the missing years.*/

SELECT  t1.Country, t1.Year as Curr_Year, t1.`Life expectancy`,
		t2.Country, t2.Year as Prev_Year, t2.`Life expectancy`,
        t3.Country, t3.year as Next_Year, t3.`Life expectancy`,
        ROUND((t2.`Life expectancy` + t3.`Life expectancy`)/2,1) as Avg_Life_Expectancy
FROM world_life_expectancy t1
JOIN world_life_expectancy t2
	ON t1.Country = t2.Country 
    AND t1.Year = t2.Year + 1
JOIN world_life_expectancy t3
	ON t1.Country = t3.Country 
    AND t1.Year = t3.Year - 1
WHERE t1.`Life expectancy` = ''
;

/*We can now do what we did last time and populate our missing data with the newly created avg life expectancy column.*/


UPDATE world_life_expectancy t1
JOIN world_life_expectancy t2
	ON t1.Country = t2.Country 
    AND t1.Year = t2.Year + 1
JOIN world_life_expectancy t3
	ON t1.Country = t3.Country 
    AND t1.Year = t3.Year - 1
SET t1.`Life expectancy` = ROUND((t2.`Life expectancy` + t3.`Life expectancy`)/2,1)
WHERE t1.`Life expectancy` = ''
;

/*Now we can check that the update was successful and we see that there is no longer any rows in our table view*/

SELECT *
FROM world_life_expectancy
WHERE `Life expectancy` = ''
;

/* This ends the data cleaning portion of the project. I'll perform more cleaning during the analysis portion if anything is found that needs to be adjusted
----------------------------------------------------------------------------------------------*/

/*Exploratory Data Analysis portion of the project*/

SELECT * 
FROM world_life_expectancy
;

/*There's so much we could do with this data, so I'll try not to go too overboard with exploring it. For now I'll focus on some points that I find could be interesting to dive into. The first of which being exactly how far each country has improved their life span during the 15 year history of this data. To do this I think it'd make the most sense to get the highest and the lowest life expectancy per country.*/

SELECT Country, MIN(`Life expectancy`) as Min_Life_Expec, MAX(`Life expectancy`) as Max_Life_Expec
FROM world_life_expectancy
GROUP BY Country
;

/*While I was sifting through the data, I noticed that a few countries had a 0 for the min and max life expectancy. Obviously a country must have SOME kind of life span for their residents, this indicates a data quality issue. For now we'll filter out the countries with 0's*/ 

SELECT Country, MIN(`Life expectancy`) as Min_Life_Expec, MAX(`Life expectancy`) as Max_Life_Expec
FROM world_life_expectancy
GROUP BY Country
HAVING MIN(`Life expectancy`) <> 0 
AND MAX(`Life expectancy`) <> 0
;

/*Looking through the table has me curious about which countries have made the most improvement to their lifespan over the years, so let's check that out by subtracting each country's highest and lowest life expectancy and compare it to their starting and ending lifespans.*/ 

SELECT Country, MIN(`Life expectancy`) as Min_Life_Expec, MAX(`Life expectancy`) as Max_Life_Expec,
	   ROUND(MAX(`Life expectancy`) - MIN(`Life expectancy`),1) as Life_Increase
FROM world_life_expectancy
GROUP BY Country
HAVING MIN(`Life expectancy`) <> 0 
AND MAX(`Life expectancy`) <> 0
ORDER BY 4 desc
;

/* While I'm at it, I figured we could view the countries with the highest and lowest increase side by side.  I'll be doing this through the use of a CTE in conjunction with ROW_NUMBER and then a self join so they can appear next to each other*/

WITH Ranked_Life_Expec AS (
	SELECT Country, ROUND(MAX(`Life expectancy`) - MIN(`Life expectancy`),1) as Life_Increase,
	ROW_NUMBER() OVER (ORDER BY ROUND(MAX(`Life expectancy`) - MIN(`Life expectancy`),1) ASC) as Asc_row,
	ROW_NUMBER() OVER (ORDER BY ROUND(MAX(`Life expectancy`) - MIN(`Life expectancy`),1) DESC) as Desc_row
	FROM world_life_expectancy
    GROUP BY Country
    HAVING MIN(`Life expectancy`) <> 0 
	AND MAX(`Life expectancy`) <> 0
)
Select highest.Country, highest.Life_Increase as Highest_Life_Increase,
	   lowest.Country, lowest.Life_Increase as Lowest_Life_Increase
FROM Ranked_Life_Expec highest
JOIN Ranked_Life_Expec lowest
	ON highest.Desc_row = lowest.Asc_row
;

/*From our query, we can see that there is a pretty substantial gap between the lowest and the highest improvements. Haiti, Zimbabwe, and Eritrea being in the top 3 highest improved life spans. While we have Guyana, Seychelles, and Kuwait at the lowest increase. This makes sense that the more impoverished countries would be able to improve the most compared to the more well-developed countries because it's far easier to improve when the life expectancy is lower than it is when the life span is in the 70s. Of course this is a generalization. There is more that plays into this such as the country's GDP and improvements to healthcare.*/

/*Having looked through lifespan increases by country, I thought it interesting to look at it by year and see the average life span by year. From there we can see what the average increase was over that 15 year time span.*/

Select Year, ROUND(AVG(`Life expectancy`),2) as Avg_Life_Expectancy
From world_life_expectancy
WHERE `Life expectancy` <> 0
GROUP BY Year
Order by Year
;

/*Seems like the average life execpectancy increased from 66.75 to 71.62. This makes an almost 5 year improvement to the average life span which I find really amazing, who knows what the lifespan will be like by the time I'm old and grey*/

Select * 
From world_life_expectancy
;

/*I'm curious as to see if there is any coorelation that we can draw between life expectancy and a few other factors such as BMI or the country's GDP. In a previous project I went through regarding COVID data, that data suggested that generally as a country's GDP increases, so does their life expectancy, so I'm curious if that will hold true with this different data set. But first I want to look at BMI.*/

SELECT Country, ROUND(AVG(`life expectancy`),1) as Avg_Life_Expec, ROUND(AVG(BMI),1) as Avg_BMI
FROM world_life_expectancy
WHERE `life expectancy` <> 0
GROUP BY Country
ORDER BY 3 asc
; 

/*There seems to be a few 0s in the BMI column, like there was for the life expectancy column. These can be difficult to populate without external research since the data found in our dataset is not capable of telling us the BMI for other countries that aren't already provided. This also indicates a data quality issue and we'll be ignoring  the 0s for this project as it doesn't seem like it will affect our data much at all considering there's only 2 missing countries.*/

SELECT Country, ROUND(AVG(`life expectancy`),1) as Avg_Life_Expec, ROUND(AVG(BMI),1) as Avg_BMI
FROM world_life_expectancy
WHERE `life expectancy` <> 0
GROUP BY Country
HAVING ROUND(AVG(BMI),1) <> 0 
ORDER BY 3 asc
; 

/*It's difficult to see with so few limited Countries in the table view below, but what I'm seeing as I scroll through the list is that generally speaking, as the BMI increases, so does the life expectancy. This was a bit surprising to me because I assumed that as the average BMI went up (past what was considered to be a healthy weight) that the life expectancy would shrink some. But aside from a few outliers, the general trend is a positive one. This will be easier to see once I bring this data to tableau and can make a visualization of it. Below you will find the top 10 countries with the highest and lowest BMI.*/

WITH Ranked_BMI AS (
	SELECT Country, ROUND(AVG(`Life expectancy`),1) as Avg_Life_Expec,
    ROUND(AVG(BMI),1) as Avg_BMI,
	ROW_NUMBER() OVER (ORDER BY ROUND(AVG(BMI),1) ASC) as Asc_row,
	ROW_NUMBER() OVER (ORDER BY ROUND(AVG(BMI),1) DESC) as Desc_row
	FROM world_life_expectancy
    WHERE `life expectancy` > 0
    GROUP BY Country
    HAVING ROUND(AVG(BMI),1) > 0
	
)
Select highest.Country, highest.Avg_Life_Expec as Highest_Avg_Life_Expec, highest.Avg_BMI as Highest_Avg_BMI,
	   lowest.Country, lowest.Avg_Life_Expec as Lowest_Avg_Life_Expec, lowest.Avg_BMI as Lowest_Avg_BMI
FROM Ranked_BMI highest
JOIN Ranked_BMI lowest
	ON highest.Desc_row = lowest.Asc_row
limit 10
;

/*We'll now switch over to look at the avg life expectancy based on a country's GDP and see if there is any type of coorelation*/

Select Country, ROUND(AVG(`life expectancy`),1) as Avg_Life_Expectancy, ROUND(AVG(GDP),1) as Avg_GDP
From world_life_expectancy
Group by Country
;

/*I'm seeing a few 0s in life expectancy which was expected based on earlier exploration, but I'm also seeing quite a few 0s in the GDP column. A lot of the countries with 0s appear to be smaller countries, so it could be that some of these countries refused to give up the data to whoever was collecting the data at the time. Nevertheless, I wanted to acknowledge it and make note that the countries with 0s will be ignored going forward.*/

Select Country, ROUND(AVG(`life expectancy`),1) as Avg_Life_Expectancy, ROUND(AVG(GDP),1) as Avg_GDP
From world_life_expectancy
Group by Country
Having Avg_Life_Expectancy <> 0 
AND Avg_GDP <> 0
Order by 3 asc
;

/*Looking back at our avg life expectancy from a previous query, I can see that the avg life expectancy was about 68 years. So any country below that would be behind the worldwide average. while scrolling through the data, I noticed that with the exception of 3 or 4 countries, every country with an avg gdp in the last 15 years (I believe this is per capita, but I'm not certain) below the 1400~ their live expectancy is below that 68 average and the opposite is true for those above that threshold. I was curious about why I wasn't finding the United States on the table and I figured out that the GDP for America is filled with a 0. So it was filtered out by my query. I'll be able to figure out the coorelation between gdp and life expectancy once I pull this data into tableau. But for now we can somewhat see this coorelation more easily through the use of Case statements. I'll add up the number of countries with a GDP higher than 1200 and their avg life expectancy, along with countries with a lower GDP than 1200 and their avg life expectancy.*/

Select 
SUM(Case When GDP >= 1200 Then 1 Else 0 END) High_GDP_Count,
ROUND(AVG(Case When GDP >= 1200 Then `life expectancy` Else NULL End),2) High_GDP_Life_Expectancy,
SUM(Case When GDP <= 1200 Then 1 Else 0 END) Low_GDP_Count,
ROUND(AVG(Case When GDP <= 1200 Then `life expectancy` Else NULL End),2) Low_GDP_Life_Expectancy
From world_life_expectancy
;

/*I missed around with the GDP number to use in the case statement a few times starting at 1400 and then lowering it until I got to a good general middle point in the data. And from the data, we can see that the upper half of the countries with higher GDP tend to have a much higher life expectancy than those with a lower GDP. The gap is almost 10 years between the two.*/

/*This comparison between the upper and lower GDP countries has me curious about the countries marked as developing vs those that are developed. So let's look at the avg life expectancy and GDP of those two side by side */












