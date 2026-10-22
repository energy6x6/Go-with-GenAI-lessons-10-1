package main

import (
	"context"
	"fmt"

	"github.com/aws/aws-lambda-go/lambda"
)

type Event struct {
	Name string `json:"name"`
}

type Response struct {
	StatusCode int    `json:"statusCode"`
	Body       string `json:"body"`
}

func handler(_ context.Context, event Event) (Response, error) {
	name := event.Name
	if name == "" {
		name = "world"
	}
	return Response{
		StatusCode: 200,
		Body:       fmt.Sprintf("hello, %s from floci", name),
	}, nil
}

func main() {
	lambda.Start(handler)
}
