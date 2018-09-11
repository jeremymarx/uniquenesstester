/*
	Tests for Uniqueness among columns in a given table or all tables, and allows testing composites.
	By: Jeremy Marx, 2016-04-01
	Version 0.3.0

	Description:
		For a given (or every) table, this script will examine the data in each column as a silo, determining if the column data is truly unique, unique with nulls, or unique with a single null.
		Silos can also be defined as multiple columns, called Composite (key) Candidates, to test for uniqueness when combining columns.

		For example: In a typical Order Detail table, OrderId may not be unique, but OrderId and OrderDetailId together might be unique. Composite Candidates can test this.
	

	Instructions:
		To test all tables: 
			1. Leave @Table undefined. 
			2. Run.
			Caution: Can be resource-heavy and/or long-running. Not recommended for production servers.
		
		To test a specific table: 
			All columns:
				1. Set @Schema and @Table.
				2. Comment out insert statement for #CompositeCandidates.
				3. Run.
			One or more composite candidates:
				1. Set @Schema and @Table.
				2. Using insert statement for #CompositeCandidates, define your candidate(s).
				3. Run.

	Explanation of Results:
		- UNIQUE means no duplicate values and no NULLs (can either be a PK or have a unique constraint/index).

		- UNIQUE WITH SINGLE NULL – as can be guessed, no duplicates, but there's one NULL (cannot be a PK, but can have a unique constraint/index).

		- UNIQUE with NULLs – no duplicates, two or more NULLs (in case you are on SQL Server 2008, you could have a conditional unique index for non-NULL values only).

		- empty string – there are duplicates, possibly NULLs too.

	Todo:
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


	#Changelog (Semantic Versioning):	

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

*/

USE AdventureWorks2017;
GO

-- Set Schema and Table
DECLARE 
		@Schema NVARCHAR(100) = 'HumanResources'
	  , @Table NVARCHAR(100)  = 'EmployeeDepartmentHistory'

-- Clean the environment
IF OBJECT_ID('tempdb..#CompositeCandidates', 'U') IS NOT NULL 
DROP TABLE #CompositeCandidates; 

-- Define Composite Candidates, if any.
CREATE TABLE [#CompositeCandidates] (
       [CandidateId] TINYINT NOT NULL
	 , [OrderId] TINYINT NOT NULL
     , [ColumnName] NVARCHAR(100) NOT NULL);

INSERT INTO [#CompositeCandidates]
        ([CandidateId], [OrderId], [ColumnName])
VALUES  (1, 1, 'BusinessEntityID'),
		(1, 2, 'DepartmentID'),
		(2, 1, 'DepartmentID'),
		(2, 2, 'ShiftID'),
		(3, 1, 'BusinessEntityID'),
		(3, 2, 'DepartmentID'),
		(3, 3, 'ShiftID');

DECLARE 
		@SCDColumn NVARCHAR(100) = ''
	  , @SCDIsCurrentValue NVARCHAR(100) = ''
	  -- Leave these alone.
	  , @OuterSQL NVARCHAR(MAX)
	  , @ccApply NVARCHAR(4000) = ''
	  , @ccSelect NVARCHAR(4000) = ''
	  , @Candidate INT = 1
	  , @Column INT = 1
	  , @Candidates INT
	  , @Columns INT
	  , @nl NVARCHAR(1) = CHAR(13);

-- Process Composite Candidates
IF EXISTS (SELECT 1 FROM [#CompositeCandidates])
BEGIN
	SELECT @Candidates = MAX([CandidateId]) FROM [#CompositeCandidates] AS [cc];

	-- Process Each Set of Candidates
	WHILE @Candidate <= @Candidates
	BEGIN
		SET @Column = 1;
		
		-- Build select.
		SET @ccSelect = @ccSelect + 'CASE COUNT(DISTINCT [CompositeCandidate' + CAST(@Candidate AS NVARCHAR(3)) + ']) WHEN COUNT(*) THEN ''''UNIQUE'''' WHEN COUNT(*) - 1 THEN CASE COUNT(DISTINCT [CompositeCandidate' + CAST(@Candidate AS NVARCHAR(3)) + ']) WHEN COUNT([CompositeCandidate' + CAST(@Candidate AS NVARCHAR(3)) + ']) THEN ''''UNIQUE WITH SINGLE NULL'''' ELSE '''''''' END WHEN COUNT([CompositeCandidate' + CAST(@Candidate AS NVARCHAR(3)) + ']) THEN ''''UNIQUE with NULLs'''' ELSE '''''''' END AS [CompositeCandidate' + CAST(@Candidate AS NVARCHAR(3)) + ']' + @nl;
		IF @Candidate < @Candidates 
			SET @ccSelect = @ccSelect + ',';
		
		-- Build cross apply.
		SET @ccApply = @ccApply + @nl + 'CROSS APPLY (SELECT ';

        SELECT  @Columns = MAX([OrderId])
        FROM    [#CompositeCandidates] AS [cc]
        WHERE   [CandidateId] = @Candidate;
		
		-- Process Columns
		WHILE @Column <= @Columns
		BEGIN
			-- Add column to cross apply, cast to string.
			SELECT	@ccApply = @ccApply + 'CAST(' + QUOTENAME([ColumnName]) + ' AS NVARCHAR(MAX))'
			FROM	[#CompositeCandidates]
			WHERE	[Candidateid] = @Candidate AND
					[OrderId] = @Column;
		
			IF @Column < @Columns
				SET @ccApply = @ccApply + ' + ''''&^&'''' + '; 
		
			SET @Column = @Column+1;
		END
		
		-- Add tail to cross apply.
		SET @ccApply = @ccApply + ' AS [CompositeCandidate' + CAST(@Candidate AS NVARCHAR(3)) + ']) AS [ca' + CAST(@Candidate AS NVARCHAR(3)) + ']';
		SET @Candidate = @Candidate+1;
	END
END

-- Build outer SQL statement.

SELECT @OuterSQL = '
-- Set up variables.
DECLARE @Table NVARCHAR(100), @Schema NVARCHAR(100), @InnerSQL NVARCHAR(MAX)=''''; SELECT @Table = parsename(''?'', 1), @Schema = parsename(''?'', 2);';

IF NOT EXISTS (SELECT 1 FROM [#CompositeCandidates])
BEGIN
	SELECT @OuterSQL = @OuterSQL + '
	-- Build select for all columns.
	SELECT 
	  @InnerSQL = COALESCE(@InnerSQL + '', '', '''') + ColumnExpression
	FROM (
	  SELECT
		ColumnExpression =
		  ''CASE COUNT(DISTINCT '' + QUOTENAME(COLUMN_NAME) + '') '' +
		  ''WHEN COUNT(*) THEN ''''UNIQUE'''' '' +
		  ''WHEN COUNT(*) - 1 THEN '' +
			''CASE COUNT(DISTINCT '' + QUOTENAME(COLUMN_NAME) + '') '' +
			''WHEN COUNT('' + QUOTENAME(COLUMN_NAME) + '') THEN ''''UNIQUE WITH SINGLE NULL'''' '' +
			''ELSE '''''''' '' +
			''END '' +
		  ''WHEN COUNT('' + QUOTENAME(COLUMN_NAME) + '') THEN ''''UNIQUE with NULLs'''' '' +
		  ''ELSE '''''''' '' +
		  ''END AS '' + QUOTENAME(COLUMN_NAME)
	  FROM INFORMATION_SCHEMA.COLUMNS
	  WHERE TABLE_NAME = @Table AND
			[TABLE_SCHEMA] = @Schema
	) s;';
END

SELECT @OuterSQL = @OuterSQL + '
	-- Frame column selects inside greater select query, including additional cross applies (if any), additional environmental data (such as table name).
	SET @InnerSQL = ''SELECT  ''''?'''' AS [Table] ' + @nl +
	CASE LEN(@ccSelect) WHEN 0 THEN '' ELSE ', ' + @ccSelect END + ''' + @InnerSQL + '' FROM ? ' + @nl + @ccApply + @nl +
	-- Build SCD exclusion if defined.
	CASE LEN(@SCDColumn) WHEN 0 THEN '' ELSE 'WHERE ' + QUOTENAME(@SCDColumn) + 
		CASE WHEN @SCDIsCurrentValue IS NULL THEN ' IS NULL' ELSE ' = ''''' + @SCDIsCurrentValue + '''''' END 
	END + @nl + ''';

	EXEC (@InnerSQL);';

-- Run the query
IF (@Table IS NOT NULL) -- Single Table.
	BEGIN
		-- Replace placeholders with table values.
		SELECT @OuterSQL = REPLACE(@OuterSQL, '?', QUOTENAME(@schema)+'.'+QUOTENAME(@table));
		-- Run statement.
		PRINT @OuterSQL;
		EXEC (@OuterSQL);
	END
ELSE -- All tables.
	BEGIN
		-- If no table was specified, run for all.
		EXEC [sys].[sp_MSforeachtable] @command1 = @OuterSQL;
	END

