
Feature: Administer inventory pools

  As an administrator
  I want to have admin tools spanning the entire system
  So that I can create, update and edit inventory pools

  @javascript @personas
  Scenario: Choosing an inventory pool
    Given I am Gino
    When I navigate to the admin area
    Then I see the list of all inventory pools
    When I click the navigation toggler
    Then I see all managed inventory pools
    And the list of inventory pools is sorted alphabetically

  @personas
  Scenario: Creating an initial inventory pool
    Given I am Gino
    When I create a new inventory pool in the admin area's inventory pool tab
    And I enter name, shortname and email address
    And I save
    Then I see the list of all inventory pools
    And I receive a notification
    And the inventory pool is saved

  @personas
  Scenario Outline: Required fields when creating an inventory pool
    Given I am Ramon
    When I create a new inventory pool in the admin area's inventory pool tab
    And I don't enter <required_field>
    And I save
    Then I see an error message
    And the inventory pool is not created
    Examples:
      | required_field |
      | Name        |
      | Short Name    |
      | E-Mail      |

  @personas
  Scenario: Editing inventory pool
    Given I am Ramon
    When I edit in the admin area's inventory pool tab an existing inventory pool
    And I change name, shortname and email address
    And I save
    Then the inventory pool is saved

  @javascript @personas
  Scenario: Delete inventory pool
    Given I am Ramon
    When I delete an existing inventory pool in the admin area's inventory pool tab
    Then the inventory pool is removed from the list
    And the inventory pool is deleted from the database

  @personas
  Scenario: Automatically grant access to new users
    Given I am Gino
    And multiple inventory pools are granting automatic access
    And I am listing users
    When I have created a user with login "username" and password "password"
    Then the newly created user has 'customer'-level access to all inventory pools that grant automatic access

