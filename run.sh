export NVSHMEM_IB_ENABLE_IBGDA=1

# Try again
mpirun --allow-run-as-root\
       -np 2 --bind-to none \
       -x CUDA_VISIBLE_DEVICES=0,1 \
       -x NVSHMEM_BOOTSTRAP=MPI \
       /tmp/nvshmem_src/build/perftest/device/coll/barrier_latency -i 1000

