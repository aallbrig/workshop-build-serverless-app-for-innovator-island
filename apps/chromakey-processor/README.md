# Chromakey processor

This is another lambda function whose workshop instruction is to manually set it up, but I instead am setting it up as a SAM app.

💪=(^ . ^)=

## Notes
Lmao, get this when I try to create a lambda event trigger on an S3 bucket event on an S3 bucket from another cloudformation stack template I get this error...

```text
Error: Failed to create changeset for the stack: chromakey-processor, ex: Waiter ChangeSetCreateComplete failed: Waiter encountered a terminal failure state: For expression "Status" we matched expected path: "FAILED" Status: FAILED. Reason: Transform AWS::Serverless-2016-10-31 failed with: Invalid Serverless Application Specification document. Number of errors found: 1. Resource with id [ChromakeyProcessor] is invalid. Event with id [S3BucketTrigger] is invalid. S3 events must reference an S3 bucket in the same template.
```

Apparently I can either move the lambda definition to the original template that the S3 bucket is defined or [use event bridge](https://stackoverflow.com/questions/56503098/how-to-create-s3-and-triggered-lambda-in-2-different-cloudformation-templates) to circumvent this error. But like... I wonder why this restriction is in place.

Lol. Maybe I understand a little more why some of these manual steps are manual.
