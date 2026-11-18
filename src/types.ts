export type DatingIntention='Long-term relationship'|'Serious, open to seeing where it goes'|'Casual dating'|'New friends'|'Activity partner'|'Still figuring it out'
export type GenderCategory='woman'|'man'|'non_binary'|'self_described'
export type HangoutPersonality='Coffee'|'Explore'|'Foodie'|'Music'|'Culture'|'Markets'|'Parks'|'Fitness'|'Games'|'Nightlife'|'Nature'|'Community'
export type Profile={id:string;first_name:string;birth_date:string|null;bio:string;photo_url:string|null;interests:string[];hangout_personality:HangoutPersonality[];custom_hangout_personality:string|null;additional_photo_urls:(string|null)[];facebook_url:string|null;instagram_url:string|null;tiktok_url:string|null;dating_intention:DatingIntention;gender_identity:GenderCategory|null;gender_identity_detail:string|null;interested_in_genders:GenderCategory[];open_to_all_genders:boolean;created_at:string}
export type Place={id:string;osm_type:string;osm_id:string;name:string;display_name:string;lat:number;lon:number}
export type ProfilePlace={profile_id:string;place_id:string;position:number;place?:Place}
