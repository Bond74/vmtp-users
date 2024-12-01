import { APIGatewayProxyResult } from "aws-lambda";
export class VmtpRequestError extends Error {
    statusCode: number;
    constructor (msg: string, statusCode: number) {
        super();
        this.message = msg;
        this.statusCode = statusCode;
    }
}

export interface IVtmpUser {
    id: string;
    email: string;
    firstName: string;
    lastName: string;
    [Key: string]: string;
}

export interface IVmtpUsersAPIResult {
    statusCode: number;
    body: IVtmpUser[];
}