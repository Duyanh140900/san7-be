/** Hàng đợi hệ thống dùng chung giữa api (đẩy job) và worker (xử lý). */
export const SYSTEM_QUEUE = 'system';

/** Tên job trong SYSTEM_QUEUE. */
export const Jobs = {
  ping: 'ping',
  /** Hết hạn một yêu cầu nhận kèo: data { requestId } */
  requestExpire: 'request.expire',
  /** Nhả lượt giữ sân hết hạn: data { bookingId } */
  bookingExpire: 'booking.expire',
  /** Nhắc nhập kết quả sau giờ kết thúc trận: data { matchId } */
  matchPromptResult: 'match.prompt_result',
  /** Gửi FCM cho các thông báo: data { notificationIds } */
  pushSend: 'push.send',
  /** Công bố lịch đăng kèo: data { scheduleId } */
  postSchedulePublish: 'post-schedule.publish',
} as const;
