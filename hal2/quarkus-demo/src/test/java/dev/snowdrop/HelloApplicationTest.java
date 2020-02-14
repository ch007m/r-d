package dev.snowdrop;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;

@QuarkusTest
public class HelloApplicationTest {

    @Test
    public void testHelloEndpoint() {
        given()
          .when().get("/hello/polite/charles")
          .then()
             .statusCode(200)
             .body(is("Good afternoon,charles"));
    }

}