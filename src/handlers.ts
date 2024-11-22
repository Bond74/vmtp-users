
import { APIGatewayProxyEvent, APIGatewayProxyResult, SQSEvent } from "aws-lambda";
import { DynamoDBClient, ScanCommand, ScanCommandInput } from "@aws-sdk/client-dynamodb";
import { DEFAULT_REGION } from "./constants";
import { VmtpRequestError } from "./types";
import { inspect } from "util";

const dynamoClient = new DynamoDBClient({ region: process.env?.REGION || DEFAULT_REGION });
const tableName = process.env?.USERS_TABLE || "";

export const listUsers = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const params: ScanCommandInput = {
      TableName: tableName,
      ExpressionAttributeNames: {
        "#EM": "email",
        "#FN": "firstName",
        "#LN": "lastName",
        "#disabled": "disabled"
      },
      FilterExpression: '#disabled = :isDisabled',
      ExpressionAttributeValues: {
        ':isDisabled': {"S": "false"}
      },
      ProjectionExpression: "#FN, #LN, #EM",
    }
    const scanCmd = new ScanCommand (params);
    const data = [];
    let lastEvaluatedKey;
    do {
      const response = await dynamoClient.send(scanCmd);
      console.log("Items in Response: ", response.Count);
      data.push(response.Items);
      lastEvaluatedKey = response.LastEvaluatedKey;
    } while ( lastEvaluatedKey );
    
    return getApiResponse(200, JSON.stringify(data)) ;
        
  } catch (error) {
    console.error(inspect(error, false, null));
    if(error instanceof VmtpRequestError) {
      return getApiResponse(error.statusCode, error.message)
    } else {
      const err = error as { errorMessage: string };
      return getApiResponse(500,  err?.errorMessage ?? "Something went wrong...")
    }
  }
};

export const getUser = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    return {
        statusCode: 200,
        body: "OK",
        isBase64Encoded: true,
        headers: {
          "Content-Type": "application/json"
        }
      };
}

const getApiResponse = async (statusCode: number, msg: string) => {
  return {
    statusCode,
    body: msg,
    headers: {
      "Content-Type": "application/json"
    }
  };
}