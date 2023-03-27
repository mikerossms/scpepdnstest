# Azure Curated Resource Modules

This is available as a Github repo - [Github](https://github.com/Azure/ResourceModules)

While during development is is acceptable to pull this in as a sub-module, for anything going into production it is importing to make this static.

The reason for this is that these modules are continually being updated and there is a chance it could break your build without proper testing.