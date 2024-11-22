export class VmtpRequestError extends Error {
    statusCode: number;
    constructor (msg: string, statusCode: number) {
        super();
        this.message = msg;
        this.statusCode = statusCode;
    }
}