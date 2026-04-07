export async function sleep(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export class AsyncSemaphore {
  private permits: number;
  private waiters: Array<() => void> = [];

  constructor(permits: number) {
    if (!Number.isFinite(permits) || permits < 1) {
      throw new Error('Semaphore permits must be >= 1');
    }
    this.permits = Math.floor(permits);
  }

  async acquire(): Promise<() => void> {
    if (this.permits > 0) {
      this.permits -= 1;
      return () => this.release();
    }

    await new Promise<void>((resolve) => {
      this.waiters.push(resolve);
    });

    this.permits -= 1;
    return () => this.release();
  }

  private release() {
    this.permits += 1;
    const next = this.waiters.shift();
    if (next) next();
  }
}

export async function call(url: string, payload?: any) {
  const options: RequestInit = {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
  };

  if (payload) {
    options.body = JSON.stringify(payload);
  }

  const r = await fetch(url, options);

  if (!r.ok) throw new Error("Error on call");
  
  return await r.json();
}