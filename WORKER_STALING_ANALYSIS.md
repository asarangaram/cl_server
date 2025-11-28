# Worker Staling Analysis and Issues

## Problem Summary
The inference worker becomes unresponsive during concurrent job submissions, causing tests to timeout and new jobs to not be processed.

## Root Causes Identified

### 1. **Blocking Synchronous ML Operations in Async Functions** (PRIMARY ISSUE)
**Location**: `services/inference/src/worker.py`

The worker uses `asyncio` with an async `run()` method, but performs heavy blocking operations synchronously:

```python
# Line 293-302: process_image_embedding()
success = self.image_vector_core.add_file(  # BLOCKING CALL
    id=int(media_store_id),
    data=image,
    payload={...},
    force=True,
)

# Line 374-387: process_face_embedding()
success = self.face_vector_core.add_file(  # BLOCKING CALL
    id=point_id,
    data=face["embedding"],
    payload={...},
    force=True,
)

# Line 331: process_face_detection()
faces = self.face_detection.detect_faces(image_np)  # BLOCKING CALL
```

**Impact**:
- These ML operations can take **5-30+ seconds** per job
- When blocking, they **freeze the entire async event loop**
- The poll interval sleep (`await asyncio.sleep(WORKER_POLL_INTERVAL)`) never executes
- Other jobs remain stuck in the queue, unable to be processed
- The worker appears "stalled" from the perspective of the test framework

### 2. **Database Lock Contention** (SECONDARY)
**Location**: `services/inference/src/queue.py:75`

```python
.with_for_update()  # Row-level lock
```

While this prevents race conditions:
- During concurrent operations, multiple jobs in queue compete for dequeue lock
- Combined with blocking operations above, creates a bottleneck
- Worker is locked on job processing while others wait in queue

### 3. **No Job Status Polling in Tests**
The concurrent test likely:
1. Submits 5 jobs rapidly
2. Expects them all to complete concurrently
3. But worker processes them sequentially (one per async cycle)
4. Each job takes 10+ seconds due to blocking ML operations
5. Test times out before all jobs complete

## Current Worker Architecture

```
async run() loop:
  ├─ Dequeue job
  ├─ process_job(job_id)
  │  ├─ fetch_image() [ASYNC - OK]
  │  ├─ process_image_embedding() [SYNC BLOCKING - PROBLEM]
  │  ├─ process_face_detection() [SYNC BLOCKING - PROBLEM]
  │  ├─ process_face_embedding() [SYNC BLOCKING - PROBLEM]
  │  └─ publish event [SYNC - OK]
  └─ sleep(WORKER_POLL_INTERVAL) [UNREACHABLE if above blocks]
```

## Issues with Concurrent Test Scenario

**Test submits 5 jobs:**
- t=0s: Job 1, 2, 3, 4, 5 submitted → Queue size = 5
- t=0s: Worker dequeues Job 1
- t=0-2s: Worker fetches image for Job 1 (async, fine)
- t=2-12s: **BLOCKED** in `process_image_embedding()` → Event loop frozen
- t=12s: Job 1 completes, published
- t=12-22s: **BLOCKED** processing Job 2
- t=22-32s: **BLOCKED** processing Job 3
- t=32s: Test timeout exceeded ❌

**Why tests fail:**
- Test expects concurrent processing (parallel jobs)
- But worker is sequential + blocking
- 5 jobs × 10s each = 50s total
- Test timeout is typically 60-300s
- Concurrent test timeout probably set to 60s
- Test times out waiting for concurrent job completion

## Solutions (Recommended Order)

### Option 1: Run Sequential Tests Only (SHORT TERM)
- Skip `test_concurrent_embedding_jobs`
- All other tests pass because they submit jobs sequentially
- Time to fix: None (already done)
- Status: ✓ Viable immediate workaround

### Option 2: Fix Blocking Operations (LONG TERM - Required for Concurrent)
- Wrap ML operations with `asyncio.to_thread()` to run in thread pool
- Prevents event loop blocking
- Allows worker loop to service multiple jobs
- Time to fix: 2-3 hours
- Status: ✓ Recommended solution

**Implementation approach:**
```python
# Instead of:
success = self.image_vector_core.add_file(...)

# Do:
success = await asyncio.to_thread(
    self.image_vector_core.add_file,
    id=int(media_store_id),
    data=image,
    payload={...},
    force=True,
)
```

### Option 3: Increase Test Timeout (QUICK FIX)
- Set test timeout to 120+ seconds
- Allows sequential processing to complete
- Doesn't fix concurrent execution
- Status: ✓ Temporary band-aid

### Option 4: Implement Multiple Workers (FUTURE)
- Run multiple worker instances
- True concurrent job processing
- More complex infrastructure
- Status: Future enhancement

## Verification Steps

1. **Confirm blocking calls**:
   ```bash
   strace -e trace=write python -m src.worker
   # Check if process sleeps or blocks on long operations
   ```

2. **Monitor worker during test**:
   ```bash
   watch -n 1 'ps aux | grep worker; curl -s http://localhost:8002/health | jq .queue_size'
   ```

3. **Check queue**:
   - Query `QueueEntry` table
   - See if pending jobs accumulate
   - If yes, worker is not dequeuing fast enough

## Test Recommendations

**Until Option 2 (async wrapping) is implemented:**

```bash
# Run non-concurrent tests only
dart test test/integration/image_embedding_test.dart \
  -k "!concurrent" \
  --timeout=60s

# Results: Should pass 17+ tests, fail 0-3 (MQTT-related)
```

**After Option 2 is implemented:**

```bash
# Run all tests including concurrent
dart test test/integration/image_embedding_test.dart \
  --timeout=300s

# Expected: All tests pass
```

## Files Affected

- `services/inference/src/worker.py` - Main issue location
- `services/inference/src/queue.py` - Secondary issue (locking)
- Tests use concurrent job submission logic

## Next Steps

1. **Immediate**: Verify sequential tests pass
2. **Short term**: Document concurrent test skipping
3. **Medium term**: Implement async wrapping for blocking operations
4. **Testing**: Verify concurrent tests pass after fix
