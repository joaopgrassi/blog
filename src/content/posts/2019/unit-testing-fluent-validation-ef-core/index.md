---
title: "Unit testing Fluent Validation rules against EF Core entity configuration"
description: "When creating apps with EF Core and Fluent Validation, the validators can get out of sync with the entity configuration. Can we find out when they do? Yes!"
date: 2019-12-31T13:46:00+00:00
tags: ["asp.net-core", ".net-core", "entity-framework-core", "fluentvalidation"]
author: "Joao Grassi"
showToc: true
TocOpen: false
draft: false
hidemeta: true
comments: false
url: unit-testing-fluent-validation-rules-against-your-ef-core-model
type: posts

images:
- unit-testing-fluent-validation-rules-against-your-ef-core-model/fluentvalidation-efcore-cover.jpg

---

In this post, I will share with you a solution to a problem that I see often when developing ASP.NET Core apps that use both [Fluent Validation](https://fluentvalidation.net/) and [Entity Framework (Core)](https://github.com/aspnet/EntityFrameworkCore). I'll first set the scene: Show the EF Core Entity + Configuration + Fluent Validation we'll be working on. Next, I'll show the actual problem that emerges with this approach and in the end how can it be improved/solved.


**TL;DR**:

When creating apps with EF Core and Fluent Validation, the validators can get out of sync with the entity configuration (field length, required and so on). I wanted an automatic way to find out when they do and the way I achieve it was by adding unit tests for the Validators.

You can find the whole code over on GitHub: https://github.com/joaopgrassi/fluentvalidation-efcore-ruletesting. The interesting bits are `CustomerValidatorTests` and `TestExtensions`. 

**Aside**: Fluent Validation is a well-known library in the .NET community for building strongly-typed validation rules. It's very common to see it being used in ASP.NET applications since it integrates quite nicely into the model-binding infrastructure. In case you are not familiar with Fluent Validation, I recommend you take a look at their [documentation](https://fluentvalidation.net/start) to learn more and come back later 😉


## Setting the scene

In this section, I'll walk you through a simple example of building a `Customer` entity for our app. I'll show the POCO entity, it's EF Core configuration and finally the Fluent Validator for it.

### The Domain/DB side of things

Let's consider the following `Customer` entity as our main source of example:

```csharp
public class Customer
{
    public int Id { get; set; }

    public string Surname { get; set; }

    public string Forename { get; set; }

    public string Address { get; set; }
}
```

Just a [POCO](https://en.wikipedia.org/wiki/Plain_old_CLR_object) class. When using EF Core we need to "map" this entity to an actual table. EF Core does a good job of mapping our entity to actual database columns/types via its [built-in conventions](https://docs.microsoft.com/en-us/ef/ef6/modeling/code-first/conventions/built-in). For example, it will create a PK, auto-increment for our `Id` field without us doing anything. 

Although this is handy, I often like to have more control over these things. Since EF Core 2, we can define the entity's individual configuration in a [EntityTypeConfiguration](http://anthonygiretti.com/2018/01/11/entity-framework-core-2-entity-type-configuration/) file. So, for our `Customer` entity above, we could have this:

```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Shop.Data.Entities;

namespace Shop.Data
{
    public class CustomerEntityTypeConfiguration : IEntityTypeConfiguration<Customer>
    {
        public void Configure(EntityTypeBuilder<Customer> builder)
        {
            builder.HasKey(c => c.Id);
            builder.Property(c => c.Surname).IsRequired().HasMaxLength(255);
            builder.Property(c => c.Forename).IsRequired().HasMaxLength(255);
            builder.Property(c => c.Address).HasMaxLength(250);
        }
    }
}
```

The class above tells EF explicitly how we want the entity fields to be configured in our DB. The relevant part for this post is the `HasMaxLength(x)` method. This will create in our database a `VARCHAR(255)` column type. If we haven't done this, the column would be created with `VARCHAR(MAX)` which may not be what you initially wanted.

> NOTE: I'll skip all the migration generation/apply in this post since it's not the focus of it.

### The Validation side of things

Now that we have modeled and configured our Entity on the DB side, it's time to use it. Imagine that we built an ASP.NET Core API and we have a `POST` endpoint which accepts the `Customer` model in the request body:

```csharp
[HttpPost]
public async Task<IActionResult> CreateCustomer(
    Customer newCustomer, CancellationToken cancellationToken)
{
    _shopDbContext.Add(newCustomer);
    await _shopDbContext.SaveChangesAsync(cancellationToken);

    return CreatedAtRoute(
        nameof(GetById),
        new { id = newCustomer.Id }, newCustomer);
}
```

We want to be good developers and don't accept bad values for our `Customer`. For instance, we stated in our `CustomerEntityTypeConfiguration` that both `Surname` and `Forename` are `Required`. The way it is now, I could create a customer with the name `""`. Not cool. Let's now use Fluent Validation and create a rule for it:

```csharp
using FluentValidation;
using Shop.Data.Entities;

namespace Shop.API.Controllers
{
    public class CustomerValidator : AbstractValidator<Customer>
    {
        public CustomerValidator()
        {
            RuleFor(x => x.Surname)
                .NotEmpty()
                .MaximumLength(255)
                .WithMessage("Please specify a last name");

            RuleFor(x => x.Forename)
                .NotEmpty()
                .MaximumLength(255)
                .WithMessage("Please specify a first name");

            RuleFor(x => x.Address).Length(20, 250);
        }
    }
}
```
Done! Now our API does not accept invalid values anymore for our `Customer` fields. 

> **Warning**: Although I used the `Customer` entity as the parameter/response type in my POST method above, this is not a good practice in real world apps. Make sure to use DTO's/ViewModels and keep your EF entities separated. Using DTO's or ViewModels will not change the rest of the post but I chose to do this way to make it simpler.

## The actual problem

The `CustomerValidator` pretty much defines the same "constraints" as in the `CustomerEntityTypeConfiguration`. We defined the `Required` fields and the `MaxLength` they have. This is important because if the API receives a `Forename` with `256` characters, the `INSERT` statement will fail and we don't want to make a DB round-trip to discover that. The Fluent Validator enables us to short-circuit the request as soon as possible which is perfect.

But this creates a new problem. The validator is tightly coupled with our entity configuration. What if later on, another developer goes and changes the `Forename` in the `CustomerEntityTypeConfiguration` to be `200` characters long instead of `255`? Suddenly requests that were "allowed" will start to fail.

This is not just regarding the `MaxLength` side of things. For instance, `Address` is not `Required` on both sides, but what if the same developer makes it `Required` on the EF Core side? Again, failed DB inserts statements all over.

See the issue? Our Fluent Validator can become out of sync when new changes are introduced to our Domain/EF Core. It's quite normal during the app lifetime that things change so this **will** be a thing that can happen. 

Can we do something about it?

## A proposed solution - Unit Tests!

I ran into this issue myself a while ago. I could just: "I will remember to always go back and change the Fluent Validator when I change my EF Core model configuration. It's gonna be OKAY". **NOPE**, it's not. I'll forget about it and I don't want to rely on my memory. Remember, never trust yourself when it comes to these things!

I enjoy writing tests. More even when they take the "burden" of having to remember these type of things.

So I thought: Wouldn't it be nice if I could write a test which would compare my EF Core model against the validator for my entity and break if they don't match? Turns out we can!

## Creating our test

This part involved me pooking around the source code (and tests) of both Fluent Validation and EF Core. Let's start on how can we access the configuration from `CustomerEntityTypeConfiguration`.

## Obtaining `EntityTypeBuilder<T>`

When we configure our entity inside `CustomerEntityTypeConfiguration`, we work with `EntityTypeBuilder<Customer>`. During our test, we need to somehow get the builder so we can access its metadata where we can "learn" about its properties.

I went down the rabbit hole of understanding how all these things work. In a nutshel, to get an instance of `EntityTypeBuilder<Customer>`, we need first a `ModelBuilder`. If you have some experience with EF you might remember of working with it here:


```csharp
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.Entity<Blog>()
        .Property(b => b.Url)
        .IsRequired();
}
```

But it turns out to create a `ModelBuilder` I needed a bunch of other stuff. First, I needed an instance of my `DbContext`. For that I also needed an instance of `DbContextOptionsBuilder` and  [`ConventionSet`](https://docs.microsoft.com/en-us/dotnet/api/microsoft.entityframeworkcore.metadata.conventions.conventionset?view=efcore-3.1)(which tells EF how to apply its conventions). Phew!. It might sound complicated but it's not so bad. After some trial and error, I managed to get it working. Here's the code that does all of this and returns and instance of `EntityTypeBuilder<Customer>`: 

```csharp
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Microsoft.EntityFrameworkCore.Metadata.Conventions;

private EntityTypeBuilder<Customer> GetCustomerEntityConfigurationMetadata()
{
    // Construct the optionsBuilder using InMemory SqlLite
    var options = new DbContextOptionsBuilder<ShopDbContext>()
            .UseSqlite(new SqliteConnection("DataSource=:memory:"))
            .Options;

    var sut = new ShopDbContext(options);

    // Get the convention set for this db
    var conventionSet = ConventionSet.CreateConventionSet(sut);

    // Now create the ModelBuilder
    var modelBuilder = new ModelBuilder(conventionSet);

    // Get the EntityTypeBuilder for Customer
    var entityTypeBuilder = modelBuilder.Entity<Customer>();

    // Apply the EntityConfiguration to our entityTypeBuilder
    var customerEntityConfiguration = new CustomerEntityTypeConfiguration();
    customerEntityConfiguration.Configure(entityTypeBuilder);

    return entityTypeBuilder;
}
```

I'll not go into too much detail here because this alone is a post for itself, but I left comments and hopefully they help explain it. The important part is: In the end, we have an instance of `EntityTypeBuilder` with our configurations applied. Now we can do something like this:

```csharp
// Get the forename property from the builder
var foreNameProperty = entityTypeBuilder.Metadata
    .FindDeclaredProperty(nameof(Customer.Forename));

// access individual metadata of the property
var maxLength = foreNameProperty.GetMaxLength();
var isNullable = foreNameProperty.IsColumnNullable();
```

## Obtaining each `IPropertyValidator`

With the EF part out of our way, we need to somehow get the metadata about our `CustomerValidator`. I browsed the source code of Fluent Validation on GitHub and turns out there's already something I could use to get going. This was my "source of inspiration" [ValidatorDescriptor](https://sourcegraph.com/github.com/JeremySkinner/FluentValidation/-/blob/src/FluentValidation/ValidatorDescriptor.cs#L74:1-74:23).

In short, the way it works is: Inside our `CustomerValidator` we add rules for our properties. When we add things like: `NotEmpty()`, `MaximumLength(255)` we are adding validators for the property. All property validators implement the `IPropertyValidator` interface from Fluent Validation. In our validator, we have used the `NotEmptyValidator`, `LengthValidator` and `MaximumLengthValidator`.

Continuing, once we have an instance of our `CustomerValidator` we can get all of its `IPropertyValidator` for a given field. Once we have an instance of an `IPropertyValidator` we can access its configured value.

Here's a generic extension method I wrote which returns all `IPropertyValidator`s of a given member (property):

```csharp
using FluentValidation;
using FluentValidation.Internal;
using FluentValidation.Validators;
using System;
using System.Linq;
using System.Linq.Expressions;

public static IPropertyValidator[] GetValidatorsForMember<T, TProperty>(
    this IValidator<T> validator, Expression<Func<T, TProperty>> expression)
{
    var descriptor = validator.CreateDescriptor();
    var expressionMemberName = expression.GetMember()?.Name;

    return descriptor.GetValidatorsForMember(expressionMemberName).ToArray();
}

```

Now we can do this:

```csharp
// Get the LengthValidator for the ForeName property of the validator
var validator = new CustomerValidator();

// GetValidatorsForMember returns an array but we are interested only in
// the LengthValidator, so I used Linq's OfType to filter the array
var foreNameLengthValidator = validator.GetValidatorsForMember(t => t.Forename)
    .OfType<MaximumLengthValidator>().First();

// We can inspect the max value now!
foreNameLengthValidator.Max;
```

## The actual test

Okay - We have everything we need and can write our tests. Let's create one that will check if our `CustomerValidator` is implementing the correct rules for the `Forename` property in our `Customer` entity:

```csharp
[Fact]
public void ForenameRule_ShouldMatchEFModelConfiguration()
{
    var validator = new CustomerValidator();

    // Get the rules for the Forename field in the CustomerValidator
    var foreNameLengthValidator = validator.GetValidatorsForMember(t => t.Forename)
        .OfType<MaximumLengthValidator>().First();

    var foreNameNotEmptyValidator = validator.GetValidatorsForMember(t => t.Forename)
        .OfType<NotEmptyValidator>().FirstOrDefault();

    // Get the EF EntityTypeBuilder<T> for our Customer entity
    var entityTypeBuilder = GetCustomerEntityConfigurationMetadata();

    var foreNameDbProperty = entityTypeBuilder.Metadata
        .FindDeclaredProperty(nameof(Customer.Forename));

    // Rule Should have the same length as EF Configuration
    Assert.Equal(foreNameDbProperty.GetMaxLength(), foreNameLengthValidator.Max);

    // If the Column is required (NOTNULL) in the EF configuration
    // the the foreNameNotEmptyValidator should not be null
    if (!foreNameDbProperty.IsColumnNullable())
        Assert.NotNull(foreNameNotEmptyValidator);
    else
        Assert.Null(foreNameNotEmptyValidator);
}
```
Nice! Now if I go to my `CustomerValidator` and change the rules of `Forename` to the code below, the test should fail:

```csharp
RuleFor(x => x.Surname)
 .NotEmpty()
 .MaximumLength(256) // 1 character longer than the allowed
 .WithMessage("Please specify a last name");
 ```
 
 And indeed it does!
 ![Customer Validator out-of-sync with EF Model](/content/images/2019/12/Assert-validator-outofsync.png)

## Conclusion

With this approach, we can be sure that if something changes regarding either our EF Model or our validation our tests will let us know. 

For what I needed this solved the problem pretty well. I didn't dig much into all of the Validators available and more complex validations (like lists and conditions). It might require a bit more investigation, but at least the base is there and can be improved.

> It can get a bit tedious to write all of this though, so read on in case you want to see another version which makes it *a bit* better.

That's it. I hope this was useful and until next year (Sorry, I couldn't let this one slip 😅)

## Bonus - Improving things a bit

I implemented this test in 2 classes and it turned out it was quite a lot of code. Having to get each field twice (from EF Config and Fluent Validation) is very tedious. I managed to work the methods a bit and now I think things are a bit better. 

Let's say you want to test a validator which contains several `LengthValidator` rules at once. With the improved version of the extension methods we can do this:

```csharp

[Fact]
public void Validator_MaxLengthRules_ShouldHaveSameLengthAsEfEntity()
{
    var propertiesToValidate = new string[]
    {
        nameof(Customer.Surname),
        nameof(Customer.Forename),
        nameof(Customer.Address),
    };

    var entityBuilder = TestExtensions
        .GetEntityTypeBuilder<Customer, CustomerEntityTypeConfiguration>();

    // Get the validators for the fields above
    Dictionary<string, LengthValidator> validatorsDict = propertiesToValidate
        .Select(p => new { Key = p, Validator = _sut.GetValidatorsForMember(p).OfType<LengthValidator>().First() })
        .ToDictionary(key => key.Key, value => value.Validator);

    // Get the database metadata for each field as configured in EF Core
    Dictionary<string, IMutableProperty> expectedDbProperties = propertiesToValidate
        .Select(p => new { Key = p, FieldMetadata = entityBuilder.Metadata.FindDeclaredProperty(p) })
        .ToDictionary(key => key.Key, value => value.FieldMetadata);

    foreach (var propValidator in validatorsDict)
    {
        // grab the db metadata by the field name
        var expectedDbMetadata = expectedDbProperties[propValidator.Key];

        // Validator Length and Db should have the same values
        Assert.Equal(expectedDbMetadata.GetMaxLength(), propValidator.Value.Max);
    }
}
```

Now with a single test we can test all the `LengthValidator` rules of a given entity!

Photo by [Nick Karvounis](https://unsplash.com/@nickkarvounis?utm_source=unsplash&amp;utm_medium=referral&amp;utm_content=creditCopyText) on [Unsplash](https://unsplash.com/?utm_source=unsplash&amp;utm_medium=referral&amp;utm_content=creditCopyText)
