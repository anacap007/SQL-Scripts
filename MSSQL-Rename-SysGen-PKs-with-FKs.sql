/*
How to use:
Set Results to Text instead of the typical Results To Grid.
Also in the Options settings, go to Query Results - Results to Text - Maximum number of characters displayed in each column to 8000

Run the script with the above Results settings and then copy and paste the output.

*/

; WITH PK_MetaData_CTE AS
(
SELECT  SCHEMA_NAME(b.schema_id) as SchemaName,
        OBJECT_NAME(a.parent_object_id) as TableName,
        'PK_' + OBJECT_NAME(a.parent_object_id) as ProperPKName,
        a.[name] as PrimaryKeyConstraintName,
        STUFF ((SELECT ', ' + QUOTENAME(COL_NAME(c.object_id, c.column_id)) FROM sys.index_columns c WHERE c.object_id = a.parent_object_id and c.index_id = a.unique_index_id ORDER BY c.key_ordinal FOR XML PATH('')), 1, 2, '') AS ColumnNames,
        (SELECT CHAR(9) + CHAR(9) + 'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(b.schema_id)) + '.' + QUOTENAME(OBJECT_NAME(d.parent_object_id)) + ' DROP CONSTRAINT ' + QUOTENAME(d.[name]) + ';' + CHAR(13) + CHAR(10) FROM sys.foreign_keys d WHERE d.referenced_object_id = a.parent_object_id FOR XML PATH('')) AS DropForeignKeys,
        (SELECT CHAR(9) + CHAR(9) + 'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(b.schema_id)) + '.' + QUOTENAME(OBJECT_NAME(d.parent_object_id)) + ' WITH CHECK ADD CONSTRAINT ' + QUOTENAME(d.[name]) + ' FOREIGN KEY (' + STUFF((SELECT ', ' + QUOTENAME(COL_NAME(a.parent_object_id, b.parent_column_id)) from sys.foreign_keys a inner join sys.foreign_key_columns b on b.constraint_object_id = a.object_id where          a.name = d.name order by b.constraint_column_id FOR XML PATH('')), 1, 2, '') + ') REFERENCES ' + QUOTENAME(SCHEMA_NAME(b.schema_id)) + '.' + QUOTENAME(OBJECT_NAME(a.parent_object_id)) + '(' + STUFF ((SELECT ', ' + QUOTENAME(COL_NAME(c.object_id, c.column_id)) FROM sys.index_columns c WHERE c.object_id = a.parent_object_id and c.index_id = a.unique_index_id ORDER BY c.key_ordinal FOR XML PATH('')), 1, 2, '') + ')' + ';' + CHAR(13) + CHAR(10) FROM sys.foreign_keys d WHERE d.referenced_object_id = a.parent_object_id FOR XML PATH('')) AS RebuildForeignKeys,
        (SELECT CHAR(9) + CHAR(9) + 'SELECT 1 FROM ' + QUOTENAME(SCHEMA_NAME(b.schema_id)) + '.' + QUOTENAME(OBJECT_NAME(d.parent_object_id)) + ' WITH (TABLOCKX);' + CHAR(13) + CHAR(10) FROM sys.foreign_keys d WHERE d.referenced_object_id = a.parent_object_id FOR XML PATH('')) AS LockStatements 
FROM    sys.key_constraints a
        INNER JOIN sys.objects b on a.object_id = b.object_id
WHERE   a.type = 'PK'
        AND a.name <> 'PK_' + OBJECT_NAME(a.parent_object_id)
)
SELECT  'BEGIN TRY' + CHAR(13) + CHAR(10) +
        CHAR(9) + 'BEGIN TRANSACTION' + CHAR(13) + CHAR(10) +
        REPLACE(a.LockStatements, '&#x0D;', '') + CHAR(13) + CHAR(13) + CHAR(10) +
        REPLACE(a.DropForeignKeys, '&#x0D;', '') + CHAR(13) + CHAR(13) + CHAR(10) +
        CHAR(9) + CHAR(9) + 'ALTER TABLE ' + QUOTENAME(a.SchemaName) + '.' + QUOTENAME(a.TableName) + ' DROP CONSTRAINT ' + QUOTENAME(a.PrimaryKeyConstraintName) + CHAR(13) + CHAR(10) +
        CHAR(9) + CHAR(9) + 'ALTER TABLE ' + QUOTENAME(a.SchemaName) + '.' + QUOTENAME(a.TableName) + ' ADD CONSTRAINT ' + QUOTENAME(a.ProperPKName) + ' PRIMARY KEY CLUSTERED (' +  a.ColumnNames + ');' + CHAR(13) + CHAR(13) + CHAR(10) +
        REPLACE(RebuildForeignKeys, '&#x0D;', '') + CHAR(13) + CHAR(13) + CHAR(10) +
        CHAR(9) + 'COMMIT TRANSACTION' + CHAR(13) + CHAR(13) + CHAR(10) +
        'END TRY' + CHAR(13) + CHAR(13) + CHAR(10) +
        'BEGIN CATCH' + CHAR(13) + CHAR(13) + CHAR(10) +
        CHAR(9) + 'RAISERROR(''Script has encountered an error....'', 10, 1) WITH NOWAIT;'+ CHAR(13) + CHAR(10) +
        CHAR(9) + 'IF XACT_STATE() = -1'+ CHAR(13) + CHAR(10) +
        CHAR(9) + 'ROLLBACK TRANSACTION'+ CHAR(13) + CHAR(10) +
        CHAR(9) + 'THROW;'+ CHAR(13) + CHAR(10) +
        'END CATCH'  + CHAR(13) + CHAR(10) +
        'GO' + CHAR(13) + CHAR(10) AS [--Generated Script]
FROM    PK_MetaData_CTE a
WHERE   a.DropForeignKeys IS NOT NULL
ORDER BY a.TableName ASC