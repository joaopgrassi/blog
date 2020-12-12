---
title: "ASP.NET Core integration tests with docker-compose on GitHub Actions"
description: "In this post I'll demonstrate how we can run the tests for our ASP.NET Core app using `docker-compose` on GitHub Actions."
date: 2020-12-12T14:27:00+00:00
tags: ["asp.net-core", "github", "github-actions", "integration-tests", "docker"]
author: "Joao Grassi"
showToc: true
TocOpen: false
draft: false
hidemeta: true
comments: false
slug: "asp-net-core-integration-tests-with-docker-compose-github-actions"
type: posts
series: ['Integration tests in ASP.NET Core']

cover:
    image: "ghactions-dockercompose-cover.png"
    relative: true
    alt: "Octocat + GitHub Action + dotnet bot"
---

This is the forth (and last) post in the [Integration tests in ASP.NET Core](/series/integration-tests-in-asp.net-core) series.

- [Part 1: Limitations of the EF Core in-memory database providers](/limitations-ef-core-in-memory-database-providers)

- [Part 2: Using docker-compose for your ASP.NET + EF Core integration tests](/using-docker-compose-for-your-asp-net-ef-core-integration-tests)

- [Part 3: ASP.NET Core integration tests with docker-compose on Azure Pipelines](/asp-net-core-integration-tests-with-docker-compose-azure-pipelines)

- [Part 4: ASP.NET Core integration tests with docker-compose on GitHub Actions (this post)](/posts/2020/asp-net-core-integration-tests-with-docker-compose-github-actions)

In the previous post of the series we saw how to create and run our tests in a [CI](https://en.wikipedia.org/wiki/Continuous_integration) fashion using Azure Pipelines.

In this post, we'll see how to accomplish the same, but using GitHub Actions.

## TL;DR

[Go directly to the GitHub workflow yml](#workflow-yml)

[The full project on GitHub](https://github.com/joaopgrassi/dockercompose-azdevops)

## Creating our GitHub Workflow {#workflow-yml}

If you already use Azure Pipelines, you will be familiar with the concepts on GitHub Actions. A pipeline in Azure DevOps is a Workflow in GitHub Action. Nevertheless, I highly encourage you to go through the basics of GitHub Actions just so you don't feel lost [Introduction to GitHub Actions](https://docs.github.com/en/free-pro-team@latest/actions/learn-github-actions/introduction-to-github-actions).

If it's your first time dealing with this, don't worry. I'll break down each part of the workflow and explain it at a high level, as in the last post.

This is how our final workflow yml file looks like:

```yml
name: BlogAPI
env:
  DOTNET_CLI_TELEMETRY_OPTOUT: 1
on:
  push:
    paths:
      - 'src/**'
      - 'tests/**'
      - 'BlogApp.sln'
      - 'Directory.Build.props'
      - '**/blogapi-workflow.yml'
  pull_request:
    paths:
      - 'src/**'
      - 'tests/**'
      - 'BlogApp.sln'
      - 'Directory.Build.props'
      - '**/blogapi-workflow.yml'
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Check out code
        uses: actions/checkout@v2
    
      - name: Start dependencies (docker-compose)
        run: |
          docker-compose up -d  

      - name: Wait for SQL Server container
        uses: jakejarvis/wait-action@master
        with:
          time: '5s'

      - name: Install .NET Core SDK
        uses: actions/setup-dotnet@v1
        with:
          dotnet-version: '3.1.x'
    
      - name: Restore NuGet packages
        run: dotnet restore

      - name: Build
        run: dotnet build -c Release --no-restore
    
      - name: Test
        run: dotnet test -c Release --no-build
```

Let's review the steps:

### Name and env

The **name** will be the name of your workflow when you visit the "Actions" menu on your GitHub repo.

The **env** section lets you set environment variables. In this case, I'm opting out of the dotnet CLI telemetry collection.


### On (triggers)

The **on** section configures how and when the workflow runs. It is all based on hooks, and there are many of them to pick. In the example above I configured it to run on:

- each push (`push`) 
- when a pull request is open (`pull_request`)
- manually via the Actions page (`workflow_dispatch`). 

You can see all the triggers available here: [Workflow webhook events](https://docs.github.com/en/free-pro-team@latest/actions/reference/events-that-trigger-workflows#webhook-events).

In each event, you can also configure more things. In the workflow above I configured [paths](https://docs.github.com/en/free-pro-team@latest/actions/reference/workflow-syntax-for-github-actions#onpushpull_requestpaths). This will make sure that the build runs when any file changes within the configured paths. There are other things you can configure, so be sure to check the documentation.

### Jobs

The **job** section is very similar (if not the same) to Azure Pipelines. We only have one job with a handful of tasks. Check this part of the documentation to learn more about the syntax and what you can do: [Jobs](https://docs.github.com/en/free-pro-team@latest/actions/reference/workflow-syntax-for-github-actions#jobs).


#### Start dependencies (docker-compose)

As we know, our tests expect a SQL Server running on `localhost,1433`. Since Docker/compose is already installed, we just need to start it as usual with `docker-compose up -d` (-d for detached, because we don't want to block the terminal).


#### Wait for SQL Server container

Since it could take a few seconds for the SQL Server container to be up and ready to accept connections, I added this [handy GitHub Action](https://github.com/jakejarvis/wait-action) that enables us to "wait" for some time before moving to the next task. This way we are sure the tests can talk with SQL Server.


#### Restore, Build and Test

The rest of the tasks are relatively self-explanatory and don't deviate much from the commands you would normally run if you use the [.NET Core CLI](https://docs.microsoft.com/en-us/dotnet/core/tools/). But let's review them anyway:

1. First, we need to have the proper .NET Core SDK installed. For this we can use the [setup-dotnet](https://github.com/actions/setup-dotnet) GitHub Action (`actions/setup-dotnet@v1`) passing the SDK version we want.
 
2. Next, we use the normal CLI commands to `restore`, `build`, and `test` the project

That's pretty much it! Now every time you push or open a pull request the workflow will run and our tests using Docker will be executed. [See here a workflow run example](https://github.com/joaopgrassi/dockercompose-azdevops/runs/1542654298?check_suite_focus=true).


## Creating the Workflow on GitHub

GitHub actions expects our `yml` workflow files to be in a specific folder. Follow the steps:

1. In your repository, create the `.github/workflows/` directory to store your workflow files.

2. In the `.github/workflows/` directory, create a new file called `blogapi-workflow.yml` (or whatever name you want) and add the code we saw here before.

3. Commit the changes and push. Your GitHub Actions workflow is created and will run automatically!


## Summary

In this post, I showed you how we can run our tests using SQL Server on Docker over on GitHub Actions. We saw the `yml` file and we went through all the tasks that define it. If you feel a bit overwhelmed, it's OK. It takes a bit of practice to get used to the syntax but I'm sure in no time you'll master it. :sunglasses:

As a closing consideration, I wanted to point out that there's no *silver bullet* workflow, and what I presented here is just one way to do it. You could instead just write a PowerShell or Bash script that would do the same steps and your `yml` file would just run that.

That's it for this series! I hope it was useful to you and that you learned something along the way. I sure did and implemented many of the things here in my day-to-day projects. 

Thanks for reading.

[Octocat](https://github.com/logos) and the [dotnet-bot](https://github.com/dotnet/brand/blob/master/dotnet-bot-illustrations/dotnet-bot/dotnet-bot.png) image credits.
