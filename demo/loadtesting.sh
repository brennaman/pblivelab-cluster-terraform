
az container create \
-g $RESOURCE_GROUP \
-n loadtest1 \
--cpu 4 \
--memory 1 \
--image azch/artillery \
--restart-policy Never \
--command-line "artillery quick -r 1000 -d 120 $LOADTEST_API_ENDPOINT"

az container delete -n loadtest1 -g $RESOURCE_GROUP

az container create \
-g $RESOURCE_GROUP \
-n loadtest2 \
--cpu 4 \
--memory 1 \
--image azch/artillery \
--restart-policy Never \
--command-line "artillery quick -r 1000 -d 120 $LOADTEST_API_ENDPOINT"

az container delete -n loadtest2 -g $RESOURCE_GROUP

# show ratings-api pods
kgpo -l app=ratings-api -w

# monitor horizontal pod autoscaler
kubectl get hpa -n ratingsapp -w

# monitor nodes
kubectl get nodes -w 