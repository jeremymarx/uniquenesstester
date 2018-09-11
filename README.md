# uniquenesstester

Tests for Uniqueness among columns in a given table or all tables, and allows testing composites.
By: Jeremy Marx, 2016-04-01
Version 0.3.0

## Description:
For a given (or every) table, this script will examine the data in each column as a silo, determining if the column data is truly unique, unique with nulls, or unique with a single null.

Silos can also be defined as multiple columns, called Composite (key) Candidates, to test for uniqueness when combining columns.

**For example:** In a typical Order Detail table, OrderId may not be unique, but OrderId and OrderDetailId together might be unique. Composite Candidates can test this.
	

## Instructions
**To test all tables:** 

 1. List item
 2. Leave @Table undefined. 
 3. Run.
			*Caution: Can be resource-heavy and/or long-running. Not recommended for production servers.*

**To test a specific table:**
			
*All columns:*

 1. List item
 2. Set @Schema and @Table.
 3. Comment out insert statement for #CompositeCandidates.
 4. Run.

*One or more composite candidates:*

 1. Set @Schema and @Table.
 2. Using insert statement for #CompositeCandidates, define your candidate(s).
 3. Run.

Explanation of Results:
 - UNIQUE means no duplicate values and no NULLs (can either be a PK or have a unique constraint/index).
 - UNIQUE WITH SINGLE NULL – as can be guessed, no duplicates, but there's one NULL (cannot be a PK, but can have a unique constraint/index).
 - UNIQUE with NULLs – no duplicates, two or more NULLs (in case you are on SQL Server 2008, you could have a conditional unique index for non-NULL values only).
 - empty string – there are duplicates, possibly NULLs too.

## Todo
		- General
			- Add table and column validation tests (existence, etc).
		- Recognize & report
			- IDENTITY fields.
			- Defined unique constraints.
			- NULL/NOT NULL constraints.
		- All Tables Handling:
			- Insert into temp table so we can pivot the full resultset.
		- Composite Candidates Handling
			- Test for 'with NULLs'
			- Test for 'with single NULL'
		- SCD Handling
			- Handle more types of SCD columns, including multiple-column logic.
		- Test and Report
			- Composite Candidates
				- Various non-string formats.
		- Expand to data profiling tool
			- Recognize & report
				- Calculated columns
				- Suggested data types

	Not ToDo:
		- Turn into a stored procedure/function. Doing so could severely limit usability on restricted systems.
		- Change from INFORMATION_SCHEMA to DMVs. Easier to port to other systems.

	Known Issues:
		- Will break on data types that are incompatible with COUNT, such as [geography].
		- Composite Candidates do not test for 'with NULLs' or 'with single NULL'.
		- Testing all tables can be heavy on resources.


## Changelog

	## [0.3.1] - 2016-07-20 - jmarx
	### Added
	- Simple support for SCD historical row exclusion.
	
	## [0.3.0] - 2016-03-31 - jmarx
	### Added
	- Composite Candidates
	### Changed
	- Support Unicode.

	## [0.2.0] - 2016-03-30 - jmarx
	### Added
	- Specify specific table to test.

	## [0.1.0] - 2016-03-29 - jmarx
	### Added
	- Core functionality.
	- Loop through all tables in a database.

