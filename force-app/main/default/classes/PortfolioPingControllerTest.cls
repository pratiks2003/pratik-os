@IsTest
private class PortfolioPingControllerTest {
  @IsTest
  static void pingReturnsUserType() {
    Map<String, Object> result = PortfolioPingController.ping();
    Assert.areEqual(UserInfo.getUserType(), result.get('userType'));
    Assert.isNotNull(result.get('serverTime'));
  }
}
