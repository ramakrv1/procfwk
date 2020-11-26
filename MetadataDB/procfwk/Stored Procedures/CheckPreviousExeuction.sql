﻿CREATE PROCEDURE [procfwk].[CheckPreviousExeuction]
	(
	@BatchName VARCHAR(255) = NULL
	)
AS
BEGIN
	SET NOCOUNT ON;
	/*
	Check A: - Are there any Running pipelines that need to be cleaned up?
	*/

	DECLARE @BatchId UNIQUEIDENTIFIER
	DECLARE @LocalExecutionId UNIQUEIDENTIFIER

	--Check A:
	IF ([procfwk].[GetPropertyValueInternal]('UseExecutionBatches')) = '0'
		BEGIN
			IF EXISTS
				(
				SELECT 
					1 
				FROM 
					[procfwk].[CurrentExecution] 
				WHERE 
					[PipelineStatus] NOT IN ('Success','Failed','Blocked', 'Cancelled') 
					AND [PipelineRunId] IS NOT NULL
				)
				BEGIN
					--return pipelines details that require a clean up
					SELECT 
						[ResourceGroupName],
						[OrchestratorType],
						[OrchestratorName],
						[PipelineName],
						[PipelineRunId],
						[LocalExecutionId],
						[StageId],
						[PipelineId]
					FROM 
						[procfwk].[CurrentExecution]
					WHERE 
						[PipelineStatus] NOT IN ('Success','Failed','Blocked','Cancelled') 
						AND [PipelineRunId] IS NOT NULL
				END;
			ELSE
				GOTO LookUpReturnEmptyResult;
		END
	ELSE IF ([procfwk].[GetPropertyValueInternal]('UseExecutionBatches')) = '1'
		BEGIN
			IF @BatchName IS NULL
				BEGIN
					RAISERROR('A NULL batch name cannot be passed when the UseExecutionBatches property is set to 1 (true).',16,1);
					RETURN 0;
				END

			SELECT 
				@BatchId = [BatchId]
			FROM
				[procfwk].[Batches]
			WHERE
				[BatchName] = @BatchName;			
			
			SELECT
				@LocalExecutionId = [ExecutionId]
			FROM
				[procfwk].[BatchExecution]
			WHERE
				[BatchId] = @BatchId
				AND [BatchStatus] = 'Running'
				AND [EndDateTime] IS NULL;
			
			IF EXISTS
				(
				SELECT 
					1 
				FROM 
					[procfwk].[CurrentExecution] 
				WHERE 
					[LocalExecutionId] = @LocalExecutionId
					AND [PipelineStatus] NOT IN ('Success','Failed','Blocked', 'Cancelled') 
					AND [PipelineRunId] IS NOT NULL
				)
				BEGIN
					--return pipelines details that require a clean up
					SELECT 
						[ResourceGroupName],
						[OrchestratorType],
						[OrchestratorName],
						[PipelineName],
						[PipelineRunId],
						[LocalExecutionId],
						[StageId],
						[PipelineId]
					FROM 
						[procfwk].[CurrentExecution]
					WHERE 
						[LocalExecutionId] = @LocalExecutionId
						AND [PipelineStatus] NOT IN ('Success','Failed','Blocked','Cancelled') 
						AND [PipelineRunId] IS NOT NULL
				END;
			ELSE
				GOTO LookUpReturnEmptyResult;
		END
	
	LookUpReturnEmptyResult:
	--lookup activity must return something, even if just an empty dataset
	SELECT 
		NULL AS ResourceGroupName,
		NULL AS OrchestratorType,
		NULL AS OrchestratorName,
		NULL AS PipelineName,
		NULL AS AdfPipelineRunId,
		NULL AS LocalExecutionId,
		NULL AS StageId,
		NULL AS PipelineId
	FROM
		[procfwk].[CurrentExecution]
	WHERE
		1 = 2; --ensure no results
END;