/usr/bin/time -v VUS="$VUS" DURATION="$DURATION" k6 run ./src/rest/restTest.js   --out json=./results/rest/50VUS/restData.json   > ./results/rest/50VUS/restSummary.txt



/usr/bin/time -v k6 run ./src/grpc/grpcTest.js --out json=./results/grpc/grpc50vus.json > ./results/grpc/grpc50vus-summary.txt