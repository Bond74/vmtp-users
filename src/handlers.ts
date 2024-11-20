
import { APIGatewayProxyEvent, APIGatewayProxyResult, SQSEvent } from "aws-lambda";

export const listItems = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    return {
        statusCode: 200,
        body: "OK",
        isBase64Encoded: true,
        headers: {
          "Content-Type": "application/json"
        }
      };
      
}

export const getItem = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    return {
        statusCode: 200,
        body: "OK",
        isBase64Encoded: true,
        headers: {
          "Content-Type": "application/json"
        }
      };
}