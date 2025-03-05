# What this project is ?

This project is a code repository for [TDX2025 Agentforce Hackathon](https://www.salesforce.com/tdx/hackathon/).

## What I built ?

https://github.com/user-attachments/assets/d16062e5-1d99-4929-b28d-7f05a460945f

## Setup Procedure

1. First, you need to obtain an Agentfoce-enabled org.
2. Execute `sf project start deploy`.
3. Assign `Agentic App Access` permission set to the user.
4. Add an agent (or edit the default agent) in Agent Studio
5. Add topic to the agent:
    ##### Name:
    - Find account information and show sales trend report
    ##### Classification Description:
    - Engages and interacts with the user about CRM data related. This could be tasks such as identify and summarize account information, answer queries, aggregate data, find and query objects, or update records.
    ##### Scope:
    - Your job is to interact and answer questions for the user about anything Salesforce or CRM data related, combining all data retrieval functions. i.e: QueryRecords(), GetRecordDetails().   
    ##### Instructions:
    1. There are multiple available data retrieval functions at your disposal. You can use each one of them multiple times if needed. You should use functions as many times as necessary until you have all the data required to fulfill the request of the user. You can perform extra calls if you think you can get additional relevant information. You can also present the information via special user interface if it is suitable.
    2. Before you decide action to make, you should check the latest action logs of the user, which may help for understanding the users's implicit context. This should be done always after any UI-related actions are made.

6. Add following actions from the menu to the topic:
- Query Records (Beta)

7. Create following Apex Actions to the topic:
    ##### Show Account Info in UI
    - **Reference Action Type:** Apex (ShowAccountInfoAction)
    - **Agent Action Instructions:** Show Account Info to user via user interface. User can check the details of the specified account information in visual, rich, intuitive representation.
    - **Loading Text**: Showing...
    - **Input**: 
      - **recordIds**: Set ID of Account record to show details
    - **Output**
      - Whether the account information is shown to the user
    ##### Show sales trend table to user
    - **Reference Action Type:** Apex (ShowSalesTrendTableAction)
    - **Agent Action Instructions:** Show sales trend information in specified period to user.
    - **Loading Text**: Showing...
    - **Input**: 
      - **Start Date**: Start Date of the trending period. The default value would be the start date of this year.
      - **End Date**: End Date of the trending period. The default value would be the end date of this year.
    - **Output**
      - Whether the account information is shown to the user
    ##### Set Heighlight Threshold value of sales trend table
    - **Reference Action Type:** Apex (SetHeighlightThresholdAction)
    - **Agent Action Instructions:** Set Highlight Threshold value of sales trend table. It shows data highlighted in the table where value is more than the given threshold.
    - **Loading Text**: Showing...
    - **Input**: 
      - **highlightThresholds**: The threshold number to highlight the value rendered in sales table.
    - **Output**
      - Whether the account information is shown to the user
    ##### Get Latest User Action Logs
    - **Reference Action Type:** Apex (GetLatestUserActionLogsAction)
    - **Agent Action Instructions:** Check the current user's latest activity logs in user interface. You can estimate the user's implicit context. Recent action made by the user is listed.
    - **Loading Text**: Loading...
    - **Input**: 
      - **Limit**: Number of recent logs to retrieve (default: 10).
    - **Output**
      - **User Action Logs:** Formatted text of user action logs
    ##### Get Opportunities By Type And Date Range
    - **Reference Action Type:** Apex (GetOpportunitiesByTypeAndDateRangeAction)
    - **Agent Action Instructions:** Get a list of Opportunities with the specified Type and CloseDate within the given date range
    - **Loading Text**: Loading...
    - **Input**: 
      - **Start Date**: Start date of the CloseDate range.
      - **End Date**: End date of the CloseDate range.
      - **Type**: Type of the Opportunity to filter.
    - **Output**
      - **Opportunities:** List of Opportunities matching the criteria
8. Activate Agent

## Senario
1. Open `Agentic App` application from application launcher
2. Open Agentforce, and pin it to the left of the screen.
3. Chat to Agentforce, **"Tell me our sales trend of recent 3 years"**.
4. Agentforce reports the recent trend of sales revenue in matrix table in the app screen.
5. Then type **"Please highlight the revenue over $1M"** in Agentforce chat. 
6. Agentforce highlights the cells where revenue amoount is over $1M.
7. Click a cell in sales trend table which you have interest to, and then type **"Which company is most contributing to this selected revenue amount ?"** in Agentforce chat.
8. Agentforce searches opportunities in the selected period with selected type category, reasons out the account which contributes most to the selected revenue, and shows the detail information of the account in the app screen.
    - Maybe Agentforce does not show the account information in screen, just responds in chat context. In this case, type **"OK, show me the detail"** to instruct explicitly.
9. Type **"Then tell me the second-contributed company and show the details in screen."** in Agentforce chat.
10. Agent shows the detail information of the next account in the app screen.
