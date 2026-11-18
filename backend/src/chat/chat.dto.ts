import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, MaxLength, MinLength } from 'class-validator';
import { Trim } from '../common/trim.js';

export { CursorPageQuery } from '../community/community.dto.js';

export class SendMessageDto {
  @ApiProperty({
    minLength: 1,
    maxLength: 1000,
    example: 'Mấy giờ hai đội có mặt?',
  })
  @Trim()
  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  body: string;
}

export class ChatSenderDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() name: string;
  @ApiPropertyOptional({ type: String }) avatarUrl?: string | null;
}

export class MessageDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ format: 'uuid' }) matchId: string;
  @ApiProperty({ format: 'uuid', description: 'Đội của người gửi' })
  teamId: string;
  @ApiProperty() body: string;
  @ApiProperty({ type: ChatSenderDto }) sender: ChatSenderDto;
  @ApiProperty({ type: String, format: 'date-time' }) createdAt: Date;
}

export class MessagePageDto {
  @ApiProperty({ type: [MessageDto] }) items: MessageDto[];
  @ApiPropertyOptional({ type: String }) nextCursor?: string;
}

export class ChatReadDto {
  @ApiProperty({ type: String, format: 'date-time' }) lastReadAt: Date;
}

export class InboxConversationDto {
  @ApiProperty({ format: 'uuid' }) matchId: string;
  @ApiProperty({ format: 'uuid' }) teamId: string;
  @ApiProperty() teamName: string;
  @ApiProperty() crestColor: string;
  @ApiPropertyOptional({ type: MessageDto }) lastMessage?: MessageDto | null;
  @ApiProperty({ type: String, format: 'date-time' }) updatedAt: Date;
  @ApiProperty({ type: 'integer' }) unreadCount: number;
}

export class InboxDto {
  @ApiProperty({ type: [InboxConversationDto] }) items: InboxConversationDto[];
  @ApiProperty({ type: 'integer' }) unreadTotal: number;
}
