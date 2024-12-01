import { listUsers } from "./../src/handlers";
import { APIGatewayProxyEvent } from "aws-lambda";

describe("User API methods handlers tests", () => {
    it("should return error 500", async () => {
      const req = {body: null};
      const resp = await listUsers(req as APIGatewayProxyEvent);
      expect(resp.statusCode).toEqual(500);
    });
});
