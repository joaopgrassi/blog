---
title: "Limitations of the EF Core in-memory database providers"
description: "In this post we'll be looking at some of the limitations you may encounter while using the EF Core in-memory database providers for your ASP.NET Core integration tests."
date: 2020-08-09T13:08:00+00:00
tags: ["asp.net-core", ".net-core", "integration-tests", "entity-framework-core", "SQL"]
author: "Joao Grassi"
showToc: true
TocOpen: false
draft: false
hidemeta: true
comments: false
url: limitations-ef-core-in-memory-database-providers
type: posts
series: ['Integration tests in ASP.NET Core']

images:
- limitations-ef-core-in-memory-database-providers/limitations-ef-core-in-memory-database-providers-1.png

---

This is the first post in the [Integration tests in ASP.NET Core](/series/integration-tests-in-asp.net-core) series.

- [Part 1: Limitations of the EF Core in-memory database providers (this post)](/limitations-ef-core-in-memory-database-providers)

- [Part 2: Using docker-compose for your ASP.NET + EF Core integration tests](/using-docker-compose-for-your-asp-net-ef-core-integration-tests)

- [Part 3: ASP.NET Core integration tests with docker-compose on Azure Pipelines](/asp-net-core-integration-tests-with-docker-compose-azure-pipelines)

In this post we'll be looking at some of the limitations you may encounter while using the EF Core in-memory database providers for your ASP.NET Core integration tests. I'll share some real-world problems I faced while working on production ASP.NET Core apps and how I worked around them so far.

## Introduction

Writing integration tests in ASP.NET Core is a breeze. Even in cases where the app is complex (authentication, authorization, and so on) because the whole ASP.NET Core pipeline is very extensible, those things are relatively easy to circumvent and adapt during your tests. 

Integration tests make it easy to test the whole app. With a single test, you can go as far down as to your app's persistence layer, ensuring your code works. I find this very valuable and I believe it brings a high level of confidence that things are working the way they should.

Testing code that uses EF Core is also very easy thanks to the different database providers it offers. There's an in-memory database and also SQLite. They work great, are very fast and easy to use. But when your app starts to get more serious these providers start to show their limitations.

This page [Testing code that uses EF Core](https://docs.microsoft.com/en-us/ef/core/miscellaneous/testing) in the EF Core docs provides great insights about the challenges of testing code that depends on EF. I recommend reading it. Below I'll share problems that I had while working on production apps using EF Core.

## Real-world limitations with the in-memory providers


### Database schemas

If you use database schemas with EF Core and use the SQLite provider for your tests this *kinda* work. SQLite does not support multiple schemas as SQL Server does, but if you use EF Core to access/manipulate your tables, meaning you don't use raw SQL you are covered. Probably under the hood things are managed for you, since [here](https://docs.microsoft.com/en-us/ef/core/providers/sqlite/limitations) it says the migration command `EnsureSchema` is a no-op. If you use schemas in Debug mode you can see these warnings:

```shell
Microsoft.EntityFrameworkCore.Model.Validation: Warning: The entity type 'Blog' 
is configured to use schema 'app'. SQLite does not support schemas. 
This configuration will be ignored by the SQLite provider.
```

But if you **do** execute raw sql commands/queries in your app, for example:

```csharp
dbContext.Database.ExecuteSqlInterpolated(
    $"UPDATE [app].[Blogs] SET Title = {title} WHERE Id = {id});
```

This will fail with `Microsoft.Data.Sqlite.SqliteException (0x80004005): SQLite Error 1: 'no such table: app.Blogs'`. 

The way I worked-around these cases is simply checking the database provider and removing the schema from the SQL string. Something like this: 

```csharp
 var schema = "[app].";

if (Database.ProviderName == "Microsoft.EntityFrameworkCore.Sqlite")
    schema = string.Empty;

dbContext.Database.ExecuteSqlInterpolated(
    $"UPDATE {schema}[Blogs] SET Title = {title} WHERE Id = {id});

```

I only have this in one place, so it's not a big deal but still not great.

### Migrations

If your app is simple then I'd say most of the things will work regarding migrations. EF Core does a good job of rebuilding things SQLite does not support. But if your app starts to grow more complicated and especially if you write custom migrations (maybe to move data around and so on), then you'll mostly hit the limitations. This page does a great job talking about them: [SQLite EF Core Database Provider Limitations](https://docs.microsoft.com/en-us/ef/core/providers/sqlite/limitations).

### Complex queries and other things

In tutorials on the web, you see only simple CRUDs. Everything works and it's wonderful. But in real production apps, things are almost always more complicated. 

I can take a wild guess that if you are reading this you had to write at least once in your developer career a recursive query in SQL. Yes, that [CTE thingy](https://blog.sqlauthority.com/2008/07/28/sql-server-simple-example-of-recursive-cte/) that you always have to google on how to do it (thanks Pinal for saving my ass multiple times! You are a legend). 

SQLite [supports recursive queries](https://stackoverflow.com/questions/7456957/basic-recursive-query-on-sqlite3) but the syntax is different from SQL Server, so if you run in prod with SQL Server and your tests in SQLite you'll need to maintain two versions of your CTE query. 

Moreover, how do you know the CTE query works on SQL Server? (Assuming SQL Server is your production database, of course)

Okay you are a diligent developer and you tested it in a SQL Server you have somewhere during development but what if someone changes the query later? Are you 100% sure that they will always run the query on a full SQL Server? To me, that's kinda scary. 

Another point: If you use things like **OData** there's also a great chance (depending on what you do in your tests) that you'll run into troubles as well. You can argue that: One shouldn't test implementations details such as OData, but if my API serves a front-end which relies heavily on an OData query, I for sure want to have that exact query in an integration test to see if it works as we expect. That's the whole point of having integration tests.

I recently stumbled upon this question on Stack Overflow: [How to test an Entity Framework Core database as InMemory with insert functionality for a large number of rows](https://stackoverflow.com/questions/62278499/how-to-test-an-entity-framework-core-database-as-inmemory-with-insert-functional)

The OP was asking how could they run the integration tests using some set of predefined data, derived from their production database. 

For sure inserting manually is an option, but when you need a lot of data which was the OP's case having manual inserts starts to become not so nice. It simply boils down to the fact that in-memory providers are not meant for this use case in my opinion.


## Wrapping up

In this post, I presented you with some of the limitations I faced while writing integration tests for production ASP.NET + EF Core apps. I also presented what others are facing and some documentation pages that also talk about in great detail, so you can build your conclusion about it and not just rely on my biased opinion.

I'd like to point out that I still use the in-memory database providers for my integration tests. They offer a great value between feature-set and speed and work great for most use cases, but in certain scenarios, they are simply not the correct tool for the job. 

In critical parts of an app that uses data, I believe our tests must match the production environment as close as possible, for us to have confidence that when the code gets deployed things will work as predicted otherwise, we'll get phone calls during the night and... we probably don't want that 😅

Coming up next I'll show you how we can use a full SQL Server for our integration tests. Stay tuned!

[Photo by Aleksandar Pasaric from Pexels](https://www.pexels.com/photo/red-light-streaks-3312216/)



