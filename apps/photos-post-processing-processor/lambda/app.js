/*! Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *  SPDX-License-Identifier: MIT-0
 */

const AWS = require('aws-sdk')
const ddb = new AWS.DynamoDB.DocumentClient()
const iotdata = new AWS.IotData({ endpoint: process.env.IOT_DATA_ENDPOINT })
const IOT_TOPIC = 'theme-park-rides'

/* MODULE 3 - Post Processing

   This function is triggered when the final composited photo is saved to S3.
   It saves the object name to DynamoDB and alerts the front-end via IoT.
*/

// Commits the latest message to DynamoDB
const saveToDDB = async function (params) {
    try  {
        await ddb.put({
            TableName: process.env.DDB_TABLE_NAME,
            Item: {
                'partitionKey': 'user-photo',
                'sortKey': new Date().toISOString().replace(/T/, ' ').replace(/\..+/, ''),
                'objectKey': params.ObjectKey,
                'URL': params.URL
            }
        }).promise();
        console.log('saveToDDB success');
    } catch (err) {
        console.error('saveToDDB error: ', err);
    }
}

// Publishes the message to the IoT topic
const iotPublish = async function (message) {
    const wrappedMessage = JSON.stringify({
        level: 'info',
        type: 'photoProcessed',
        message
    })
    console.log('iotPublish msg: ', wrappedMessage)
    try {
        await iotdata.publish({
            topic: IOT_TOPIC,
            qos: 0,
            payload: wrappedMessage
        }).promise()
        console.log('iotPublish success')
    } catch (err) {
        console.error('iotPublish error:', err)
    }
}

// The handler invoked by Lambda.
exports.handler = async (event) => {
    console.log(JSON.stringify(event))
    console.log(JSON.stringify(context))

    s3Event = JSON.parse(event.Records[0].Sns.Message)
    console.log(JSON.stringify(s3Event))

    const params = {
        ObjectKey: s3Event.Records[0].s3.object.key,
        URL: `${process.env.WEB_APP_DOMAIN}/${s3Event.Records[0].s3.object.key}`
    }
    console.log(params)

    await saveToDDB(params);
    await iotPublish(params)

    return true
}
