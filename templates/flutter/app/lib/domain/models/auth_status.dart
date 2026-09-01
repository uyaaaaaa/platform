/// 認証状態。真実の源は AuthRepository であり、ルーティングはこれだけを見る。
enum AuthStatus { unknown, signedIn, signedOut }
