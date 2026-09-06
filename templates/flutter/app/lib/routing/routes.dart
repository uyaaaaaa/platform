abstract final class Routes {
  static const signIn = '/sign-in';
  static const items = '/items';
  static const itemEditor = '/items/:id';

  static String itemEditorOf(String id) => '/items/$id';
}
